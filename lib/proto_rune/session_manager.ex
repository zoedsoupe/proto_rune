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
  `ProtoRune.Session.refresh/2`. When `:store` and `:key` are given, each
  refreshed session is persisted encrypted via `ProtoRune.Security`.

  When a refresh fails the manager stops with `{:refresh_failed, reason}`
  and lets the supervisor decide the restart policy.

  For OAuth-specific needs (revocation on logout, `invalid_grant`
  handling), use `ProtoRune.Atproto.OAuth.SessionManager` instead.

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

  - `[:proto_rune, :session, :refresh, :start]` / `:stop` / `:exception` -
    wrap each token refresh via `:telemetry.span/3`. Metadata: `:did`;
    stop events for failed refreshes also carry `:error`.
  """

  use GenServer

  alias ProtoRune.Security
  alias ProtoRune.Session

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
        registry -> [name: {:via, Registry, {registry, Session.did(session)}}]
      end

    GenServer.start_link(__MODULE__, opts, name)
  end

  @doc """
  Returns the session currently held by `server`.
  """
  @spec session(server()) :: Session.t()
  def session(server), do: GenServer.call(server, :session)

  @impl true
  def init(opts) do
    store = Keyword.get(opts, :store)
    key = Keyword.get(opts, :key)

    if store == nil != (key == nil) do
      raise ArgumentError, ":store and :key must be given together"
    end

    state = %{
      session: Keyword.fetch!(opts, :session),
      refresh_opts: Keyword.get(opts, :refresh_opts, []),
      store: store,
      key: key,
      refresh_fraction: Keyword.get(opts, :refresh_fraction, @default_refresh_fraction)
    }

    {:ok, schedule_refresh(state)}
  end

  @impl true
  def handle_call(:session, _from, state), do: {:reply, state.session, state}

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
      {:ok, state} -> {:noreply, state}
      {:error, reason} -> {:stop, {:refresh_failed, reason}, state}
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

  defp persist(%{store: nil}, _session), do: :ok

  defp persist(%{store: store, key: key}, session) do
    Security.save_session(session, key, store)
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
