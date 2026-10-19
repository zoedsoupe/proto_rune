defmodule ProtoRune.Bot.Jetstream do
  @moduledoc """
  A GenServer module that streams real-time events from the AT Protocol
  Jetstream and dispatches them to the bot server.

  The `Jetstream` strategy is an alternative to `ProtoRune.Bot.Poller`: instead
  of periodically fetching the bot's notifications, it keeps a WebSocket
  connection to a Jetstream instance and dispatches every decoded event to the
  bot server through the same `{:handle_event, event, payload}` message used by
  the other strategies.

  Unlike the firehose strategy (`ProtoRune.Bot.Firehose`), Jetstream applies
  the `wanted_collections` / `wanted_dids` filters server-side and ships plain
  JSON text frames, so a bot receives (and pays to decode) only the events it
  asked for.

  The WebSocket connection, JSON decoding, reconnection and backoff are
  delegated to `ProtoRune.Jetstream`; this module only translates
  `ProtoRune.Jetstream.Event` structs into bot events.

  ## Dispatched events

  - `:commit` - one event per commit operation. The payload contains `:repo`
    (the repository DID), `:rev`, `:seq` (the `time_us` cursor), `:time`,
    `:action` (`:create`, `:update` or `:delete`), `:path`
    (`"collection/rkey"`), `:cid` and `:record` (the decoded record, `nil` for
    deletions).
  - `:identity`, `:account`, `:unknown` - one event per Jetstream message of
    that type. The payload contains `:repo`, `:seq`, `:time` and the raw
    decoded message under `:payload`.

  ## Options

  - `:name` (required) - The name of the GenServer instance.
  - `:server_pid` (required) - The bot server process that receives the events.
  - `:relay` - The Jetstream base URL
    (default: `"wss://jetstream2.us-east.bsky.network"`).
  - `:wanted_collections` - AT-URI collections to receive commit events for
    (server-side filter, default: all).
  - `:wanted_dids` - Restrict events to these repository DIDs (default: all).
  - `:cursor` - A `time_us` timestamp to resume the stream from (default: live
    events only).
  - `:auto_reconnect` - Reconnect automatically when the connection drops
    (default: `true`).
  - `:backoff_initial` / `:backoff_max` - Reconnect backoff bounds in milliseconds
    (default: `1_000` / `30_000`). The delay doubles after each failed attempt and
    resets once connected.
  - `:transport` / `:transport_opts` - The `ProtoRune.Firehose.Transport`
    implementation to use and its options (default: `ProtoRune.Firehose.Transport.Mint`).

  ## Example

  ```elixir
  ProtoRune.Bot.Jetstream.start_link([
    name: :my_bot_jetstream,
    server_pid: self(),
    wanted_collections: ["app.bsky.feed.post"]
  ])
  ```
  """

  use GenServer

  alias ProtoRune.Bot.Jetstream.State
  alias ProtoRune.Jetstream
  alias ProtoRune.Jetstream.Event

  @type option ::
          {:name, atom}
          | {:relay, String.t()}
          | {:wanted_collections, [String.t()]}
          | {:wanted_dids, [String.t()]}
          | {:cursor, non_neg_integer}
          | {:auto_reconnect, boolean}
          | {:backoff_initial, pos_integer}
          | {:backoff_max, pos_integer}
          | {:transport, module}
          | {:transport_opts, keyword}
          | {:server_pid, pid}
  @type kwargs :: nonempty_list(option)

  @spec start_link(kwargs) :: GenServer.on_start()
  def start_link(opts) do
    name = Access.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the `time_us` of the last delivered event, or `nil` when no event
  has been delivered yet. Feed it back as the `:cursor` option to resume from
  this point after a restart.
  """
  @spec cursor(GenServer.server()) :: non_neg_integer | nil
  def cursor(server), do: GenServer.call(server, :cursor)

  @impl true
  def init(opts) do
    {:ok, state} = State.new(opts)
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, %State{} = state) do
    opts = [
      handler: self(),
      relay: state.relay,
      auto_reconnect: state.auto_reconnect,
      backoff_initial: state.backoff_initial,
      backoff_max: state.backoff_max,
      transport: state.transport,
      transport_opts: state.transport_opts,
      wanted_collections: state.wanted_collections,
      wanted_dids: state.wanted_dids
    ]

    opts = if state.cursor, do: Keyword.put(opts, :cursor, state.cursor), else: opts

    {:ok, pid} = Jetstream.start_link(opts)
    {:noreply, %{state | jetstream: pid}}
  end

  @impl true
  def handle_call(:cursor, _from, %State{jetstream: nil} = state) do
    {:reply, state.cursor, state}
  end

  def handle_call(:cursor, _from, %State{jetstream: pid} = state) do
    {:reply, Jetstream.cursor(pid), state}
  end

  @impl true
  def handle_info({:jetstream, %Event{} = event}, %State{} = state) do
    dispatch_event(state, event)
    {:noreply, state}
  end

  def handle_info(_message, %State{jetstream: nil} = state) do
    {:noreply, state}
  end

  def handle_info(message, %State{jetstream: pid} = state) do
    send(pid, message)
    {:noreply, state}
  end

  @impl true
  def format_status(%{log: log, state: state}) do
    %{log: log, state: Map.take(state, [:name, :relay, :cursor, :auto_reconnect])}
  end

  def format_status(key), do: key

  defp dispatch_event(%State{} = state, %Event{type: :commit} = event) do
    send(
      state.server_pid,
      {:handle_event, :commit,
       %{
         repo: event.did,
         rev: event.rev,
         seq: event.time_us,
         time: time(event.time_us),
         action: event.operation,
         path: "#{event.collection}/#{event.rkey}",
         cid: event.cid,
         record: event.record
       }}
    )
  end

  defp dispatch_event(%State{} = state, %Event{type: type} = event) do
    send(
      state.server_pid,
      {:handle_event, type, %{repo: event.did, seq: event.time_us, time: time(event.time_us), payload: event.payload}}
    )
  end

  defp time(nil), do: nil
  defp time(time_us) when is_integer(time_us), do: DateTime.from_unix!(time_us, :microsecond)
end
