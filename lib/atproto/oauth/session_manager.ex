defmodule ProtoRune.Atproto.OAuth.SessionManager do
  @moduledoc """
  A GenServer that keeps an OAuth session fresh for long-running
  applications.

  The manager is opt-in: the SDK starts no processes on its own, so add
  it to the host application's supervision tree:

      children = [
        {Registry, keys: :unique, name: MyApp.OAuthRegistry},
        {ProtoRune.Atproto.OAuth.SessionManager,
         session: session,
         client: client,
         store: {ProtoRune.Security.TokenStore.Dets, path: "/var/myapp/tokens.dets"},
         key: key,
         registry: MyApp.OAuthRegistry}
      ]

  It schedules a refresh at 75% of the remaining token lifetime (from the
  session's `expires_at`; a 30 minute lifetime is assumed when the
  session carries none), rotates the tokens through
  `ProtoRune.Atproto.OAuth.refresh/2` and persists each new session
  through the configured `ProtoRune.Security.TokenStore` backend under
  the session's DID.

  Sessions are always encrypted at rest: the serialized session is
  encrypted with `ProtoRune.Security.Crypto` before it reaches the store,
  so TokenStore backends never see plaintext. This is mandatory because
  the session's `dpop_key` is private key material, as sensitive as the
  tokens themselves.

  When a refresh fails the manager stops with `{:refresh_failed, reason}`
  and lets the supervisor decide the restart policy. `logout/1` revokes
  the refresh token (best effort: a revocation failure does not block the
  logout), deletes the stored session and stops the process.

  Hosts that manage their own processes can keep calling
  `ProtoRune.Atproto.OAuth.refresh/2` and `ProtoRune.Atproto.OAuth.revoke/2`
  directly; the manager only composes them.

  ## Options

  - `:session` - Required. The `ProtoRune.Atproto.OAuth.Session` to manage.
  - `:client` - Required. The `ProtoRune.Atproto.OAuth.Client` the session
    was issued to.
  - `:store` - Required. A `{module, opts}` `ProtoRune.Security.TokenStore`
    backend used to persist each refreshed session under its DID.
  - `:key` - Required. A `ProtoRune.Security.Crypto` key used to encrypt
    every persisted session. Generate one with
    `ProtoRune.Security.generate_key/0` and keep it outside the token
    storage (see `ProtoRune.Security`).
  - `:registry` - Optional name of a `Registry` started by the host
    application. When given, the manager registers itself under the
    session's DID and can be addressed with
    `{:via, Registry, {registry, did}}`. The SDK never starts a Registry
    itself.
  - `:refresh_fraction` - Fraction of the remaining token lifetime to wait
    before refreshing (default `0.75`). Mainly a testing escape hatch.

  ## Telemetry

  The manager emits `:telemetry` events following the same span
  conventions as the bot framework (see the `ProtoRune.Bot` moduledoc):

  - `[:proto_rune, :oauth, :refresh, :start]` / `:stop` / `:exception` -
    wrap each token refresh via `:telemetry.span/3`. Metadata: `:did`;
    stop events for failed refreshes also carry `:error`.
  - `[:proto_rune, :oauth, :revoke, :start]` / `:stop` / `:exception` -
    wrap the revocation performed by `logout/1`. Same metadata
    conventions as the refresh events.
  """

  use GenServer

  alias ProtoRune.Atproto.OAuth
  alias ProtoRune.Atproto.OAuth.Session
  alias ProtoRune.Security.Crypto

  require Logger

  @default_refresh_fraction 0.75
  # Assumed access token lifetime when the session carries no expires_at
  @default_lifetime_ms to_timeout(minute: 30)

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
        registry -> [name: {:via, Registry, {registry, session.did}}]
      end

    GenServer.start_link(__MODULE__, opts, name)
  end

  @doc """
  Returns the session currently held by `server` (a pid or, when the
  manager was started with `:registry`, a via tuple).
  """
  @spec session(server()) :: Session.t()
  def session(server), do: GenServer.call(server, :session)

  @doc """
  Revokes the session, deletes it from the store and stops the manager
  with reason `:normal`.

  Revocation is best effort: a failure is logged and emitted through
  telemetry but does not block the logout.
  """
  @spec logout(server()) :: :ok
  def logout(server), do: GenServer.call(server, :logout)

  @impl true
  def init(opts) do
    state = %{
      session: Keyword.fetch!(opts, :session),
      client: Keyword.fetch!(opts, :client),
      store: Keyword.fetch!(opts, :store),
      key: Keyword.fetch!(opts, :key),
      refresh_fraction: Keyword.get(opts, :refresh_fraction, @default_refresh_fraction)
    }

    {:ok, schedule_refresh(state)}
  end

  @impl true
  def handle_call(:session, _from, state), do: {:reply, state.session, state}

  def handle_call(:logout, _from, state) do
    revoke(state)
    _ = delete(state.store, state.session.did)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    metadata = %{did: state.session.did}

    result =
      :telemetry.span([:proto_rune, :oauth, :refresh], metadata, fn ->
        case do_refresh(state) do
          {:ok, state} -> {{:ok, state}, metadata}
          {:error, reason} -> {{:error, reason}, Map.put(metadata, :error, reason)}
        end
      end)

    case result do
      {:ok, state} -> {:noreply, state}
      {:error, reason} -> {:stop, {:refresh_failed, reason}, state}
    end
  end

  @impl true
  def format_status({:state, state}) do
    {:state, %{did: state.session.did, refresh_fraction: state.refresh_fraction}}
  end

  def format_status(key), do: key

  defp do_refresh(state) do
    with {:ok, fresh} <- OAuth.refresh(state.client, state.session),
         :ok <- persist(state, fresh) do
      {:ok, schedule_refresh(%{state | session: fresh})}
    end
  end

  defp revoke(state) do
    metadata = %{did: state.session.did}

    :telemetry.span([:proto_rune, :oauth, :revoke], metadata, fn ->
      case OAuth.revoke(state.session, client_id: state.client.client_id) do
        {:ok, :revoked} ->
          {:ok, metadata}

        {:error, reason} ->
          Logger.warning("[#{__MODULE__}] ==> Revocation failed for #{state.session.did}: #{inspect(reason)}")

          {{:error, reason}, Map.put(metadata, :error, reason)}
      end
    end)

    :ok
  end

  defp persist(%{store: {backend, opts}, key: key}, %Session{did: did} = session) do
    with {:ok, blob} <- Crypto.encrypt(:erlang.term_to_binary(session), key) do
      backend.put(did, blob, opts)
    end
  end

  defp delete({backend, opts}, did), do: backend.delete(did, opts)

  defp schedule_refresh(state) do
    Process.send_after(self(), :refresh, refresh_in(state))
    state
  end

  defp refresh_in(%{refresh_fraction: fraction, session: %Session{expires_at: nil}}) do
    round(@default_lifetime_ms * fraction)
  end

  defp refresh_in(%{refresh_fraction: fraction, session: %Session{expires_at: expires_at}}) do
    remaining_ms = max(expires_at - System.system_time(:second), 0) * 1_000
    round(remaining_ms * fraction)
  end
end
