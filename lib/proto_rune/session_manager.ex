defmodule ProtoRune.SessionManager do
  @moduledoc """
  A GenServer that keeps any `ProtoRune.Session` fresh for long-running
  applications.

  Works with both session types through the `ProtoRune.Session`
  behaviour: app-password sessions (`ProtoRune.Atproto.Session`) and
  OAuth sessions (`ProtoRune.Atproto.OAuth.Session`, which additionally
  needs its issuing client passed via `:refresh_opts`).

  The manager is opt-in: the SDK starts no processes on its own, so add
  it to the host application's supervision tree:

      children = [
        {ProtoRune.SessionManager, session: session}
      ]

      # OAuth, with persistence:
      children = [
        {Registry, keys: :unique, name: MyApp.SessionRegistry},
        {ProtoRune.SessionManager,
         session: oauth_session,
         refresh_opts: [client: client],
         store: {ProtoRune.Security.TokenStore.Dets, path: "/var/myapp/tokens.dets"},
         key: key,
         registry: MyApp.SessionRegistry}
      ]

  It schedules a refresh at 75% of the remaining token lifetime (from the
  session's `expires_at`; a 30 minute lifetime is assumed when the
  session carries none) and rotates the session through
  `ProtoRune.Session.refresh/2`. When `:store` and `:key` are given, the
  store is the source of truth across restarts: the persisted session is
  loaded back on start (preferring the newer one by `expires_at`, since
  the boot-time session may carry a refresh token an earlier manager
  already rotated away) and each refreshed session is persisted
  encrypted via `ProtoRune.Security`.

  When a refresh fails the manager stops with `{:refresh_failed, reason}`
  and lets the supervisor decide the restart policy. One exception: an
  `invalid_grant` OAuth error means the grant is permanently dead
  (revoked, expired or replayed), so the manager deletes the stored
  session and stops with `:normal` instead. `logout/1` revokes the
  session's credentials (at the authorization server for OAuth sessions,
  with `com.atproto.server.deleteSession` at the PDS for app-password
  sessions), deletes the stored session and stops the process.
  Revocation is best effort: a failure is logged and emitted through
  telemetry but does not block the logout.

  ## Options

  - `:session` - Required. The session to keep fresh.
  - `:refresh_opts` - Options forwarded to `ProtoRune.Session.refresh/2`.
    Required for OAuth sessions (`[client: client]`).
  - `:store` - A `{module, opts}` `ProtoRune.Security.TokenStore` backend
    used to persist each refreshed session. Requires `:key`.
  - `:key` - A `ProtoRune.Security.Crypto` key encrypting persisted
    sessions. Required when `:store` is given.
  - `:registry` - Optional name of a `Registry` started by the host
    application. The manager registers under the session's DID.
  - `:refresh_fraction` - Fraction of the remaining token lifetime to wait
    before refreshing (default `0.75`). Mainly a testing escape hatch.

  ## Telemetry

  The manager emits `:telemetry` events following the same span
  conventions as the bot framework (see the `ProtoRune.Bot` moduledoc):

  - `[:proto_rune, :session, :refresh, :start]` / `:stop` / `:exception` -
    wrap each token refresh via `:telemetry.span/3`. Metadata: `:did`;
    stop events for failed refreshes also carry `:error`.
  - `[:proto_rune, :session, :revoke, :start]` / `:stop` / `:exception` -
    wrap the revocation performed by `logout/1`. Same metadata
    conventions as the refresh events.
  """

  use GenServer

  alias ProtoRune.Atproto.OAuth
  alias ProtoRune.Atproto.OAuth.Session, as: OAuthSession
  alias ProtoRune.Atproto.Server
  alias ProtoRune.Atproto.Session, as: AppPasswordSession
  alias ProtoRune.HTTPClient.Backoff
  alias ProtoRune.Security
  alias ProtoRune.Session

  require Logger

  @default_refresh_fraction 0.75
  # Assumed access token lifetime when the session carries no expires_at
  @default_lifetime_ms to_timeout(minute: 30)
  @persist_retries 3
  @persist_base_delay 100
  @persist_max_delay 500

  @typedoc "A reference to a manager: a pid, a registered name or a via tuple."
  @type server :: GenServer.server()

  @doc """
  Starts a session manager. See the moduledoc for the accepted options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session = Keyword.fetch!(opts, :session)

    name =
      case Keyword.get(opts, :registry) do
        nil -> []
        registry -> [name: {:via, Registry, {registry, Session.did(session)}}]
      end

    GenServer.start_link(__MODULE__, opts, name)
  end

  @doc """
  Returns the session currently held by `server`.
  """
  @spec session(server()) :: Session.t()
  def session(server), do: GenServer.call(server, :session)

  @doc """
  Revokes the session's credentials, deletes it from the store (when one
  is configured) and stops the manager with reason `:normal`.

  Revocation is best effort: a failure is logged and emitted through
  telemetry but does not block the logout.
  """
  @spec logout(server()) :: :ok
  def logout(server), do: GenServer.call(server, :logout)

  @impl true
  def init(opts) do
    store = Keyword.get(opts, :store)
    key = Keyword.get(opts, :key)

    if is_nil(store) != is_nil(key) do
      raise ArgumentError, ":store and :key must be given together"
    end

    session = Keyword.fetch!(opts, :session)

    state = %{
      session: restore_session(store, key, session),
      refresh_opts: Keyword.get(opts, :refresh_opts, []),
      store: store,
      key: key,
      refresh_fraction: Keyword.get(opts, :refresh_fraction, @default_refresh_fraction)
    }

    {:ok, schedule_refresh(state)}
  end

  @impl true
  def handle_call(:session, _from, state), do: {:reply, state.session, state}

  def handle_call(:logout, _from, state) do
    revoke(state.session, state.refresh_opts)
    _ = delete_stored_session(state)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    did = Session.did(state.session)
    metadata = %{did: did}

    result =
      :telemetry.span([:proto_rune, :session, :refresh], metadata, fn ->
        case do_refresh(state) do
          {:ok, state} -> {{:ok, state}, metadata}
          {:error, reason} -> {{:error, reason}, Map.put(metadata, :error, reason)}
        end
      end)

    case result do
      {:ok, state} ->
        {:noreply, state}

      {:error, {:oauth_error, _status, %{"error" => "invalid_grant"}}} ->
        _ = delete_stored_session(state)
        {:stop, :normal, state}

      {:error, reason} ->
        {:stop, {:refresh_failed, reason}, state}
    end
  end

  @impl true
  def format_status({:state, state}) do
    {:state, %{did: Session.did(state.session), refresh_fraction: state.refresh_fraction}}
  end

  def format_status(key), do: key

  defp do_refresh(state) do
    with {:ok, fresh} <- Session.refresh(state.session, state.refresh_opts),
         :ok <- persist(state, fresh) do
      {:ok, schedule_refresh(%{state | session: fresh})}
    end
  end

  defp restore_session(nil, _key, session), do: session

  defp restore_session(store, key, session) do
    did = Session.did(session)

    case Security.load_session(did, key, store) do
      {:ok, stored} ->
        newer_session(stored, session)

      {:error, :not_found} ->
        session

      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] ==> Could not load the stored session for #{did}: #{inspect(reason)}")

        session
    end
  end

  defp newer_session(stored, boot) do
    stored_at = Map.get(stored, :expires_at)
    boot_at = Map.get(boot, :expires_at)

    if is_integer(boot_at) and (is_nil(stored_at) or boot_at > stored_at) do
      boot
    else
      stored
    end
  end

  defp revoke(%OAuthSession{} = session, refresh_opts) do
    client = Keyword.get(refresh_opts, :client)

    revoke_with(session, fn ->
      OAuth.revoke(session,
        client_id: client && client.client_id,
        http: Keyword.get(refresh_opts, :http, [])
      )
    end)
  end

  defp revoke(%AppPasswordSession{} = session, refresh_opts) do
    revoke_with(session, fn ->
      Server.delete_session(session, %{}, http: Keyword.get(refresh_opts, :http, []))
    end)
  end

  defp revoke(session, _refresh_opts) do
    Logger.warning("[#{__MODULE__}] ==> No revocation known for #{inspect(session.__struct__)}, skipping")
    :ok
  end

  defp revoke_with(session, fun) do
    metadata = %{did: Session.did(session)}

    :telemetry.span([:proto_rune, :session, :revoke], metadata, fn ->
      case fun.() do
        {:ok, _result} ->
          {:ok, metadata}

        {:error, reason} ->
          Logger.warning("[#{__MODULE__}] ==> Revocation failed for #{Session.did(session)}: #{inspect(reason)}")

          {{:error, reason}, Map.put(metadata, :error, reason)}
      end
    end)

    :ok
  end

  # A failed persist must not stop the manager: the restart would replay the
  # store's already-rotated refresh token and destroy the session.
  defp persist(%{store: nil}, _session), do: :ok

  defp persist(%{store: store, key: key}, session) do
    case persist_retry(store, key, session, 1) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning([
          "[#{__MODULE__}] ==> Could not persist the refreshed session for ",
          Session.did(session),
          ": ",
          inspect(reason)
        ])

        :ok
    end
  end

  defp persist_retry(store, key, session, attempt) when attempt < @persist_retries do
    case Security.save_session(session, key, store) do
      :ok ->
        :ok

      {:error, _reason} ->
        delay = Backoff.delay(attempt, base_delay: @persist_base_delay, max_delay: @persist_max_delay)
        Process.sleep(delay)
        persist_retry(store, key, session, attempt + 1)
    end
  end

  defp persist_retry(store, key, session, _attempt), do: Security.save_session(session, key, store)

  defp delete_stored_session(%{store: nil}), do: :ok

  defp delete_stored_session(%{store: store, session: session}) do
    Security.delete_session(Session.did(session), store)
  end

  defp schedule_refresh(state) do
    Process.send_after(self(), :refresh, refresh_in(state))
    state
  end

  defp refresh_in(%{refresh_fraction: fraction, session: session}) do
    case Map.get(session, :expires_at) do
      nil ->
        round(@default_lifetime_ms * fraction)

      expires_at ->
        remaining_ms = max(expires_at - System.system_time(:second), 0) * 1_000
        round(remaining_ms * fraction)
    end
  end
end
