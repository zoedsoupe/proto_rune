defmodule ProtoRune.Bot.Firehose do
  @moduledoc """
  A GenServer module that streams real-time events from the ATProto firehose and
  dispatches them to the bot server.

  The `Firehose` strategy is an alternative to `ProtoRune.Bot.Poller`: instead of
  periodically fetching the bot's notifications, it keeps a WebSocket connection to
  a relay's `com.atproto.sync.subscribeRepos` endpoint and dispatches every decoded
  event to the bot server through the same `{:handle_event, event, payload}` message
  used by the poller.

  The WebSocket connection, CBOR decoding, reconnection and backoff are delegated to
  `ProtoRune.Firehose`; this module only translates `ProtoRune.Firehose.Event`
  structs into bot events.

  ## Dispatched events

  - `:commit` - one event per repository operation of a commit. The payload contains
    `:repo`, `:rev`, `:seq`, `:time`, `:action` (`:create`, `:update` or `:delete`),
    `:path`, `:cid` and `:record` (the decoded record, `nil` for deletions).
  - `:identity`, `:account`, `:handle`, `:migrate`, `:tombstone`, `:info`, `:error`,
    `:unknown` - one event per firehose message of that type. The payload contains
    `:repo`, `:seq`, `:time` and the raw decoded frame under `:payload`.

  ## Options

  - `:name` (required) - The name of the GenServer instance.
  - `:server_pid` (required) - The bot server process that receives the events.
  - `:relay` - The relay base URL (default: `"wss://bsky.network"`).
  - `:cursor` - The sequence number to start the stream from, for backfilling events
    missed while disconnected. Accepts an integer, a numeric string or `"latest"`
    (default: `"latest"`, meaning live events only).
  - `:auto_reconnect` - Reconnect automatically when the connection drops
    (default: `true`).
  - `:backoff_initial` / `:backoff_max` - Reconnect backoff bounds in milliseconds
    (default: `1_000` / `30_000`). The delay doubles after each failed attempt and
    resets once connected.
  - `:transport` / `:transport_opts` - The `ProtoRune.Firehose.Transport`
    implementation to use and its options (default: `ProtoRune.Firehose.Transport.Gun`).

  ## Example

  ```elixir
  ProtoRune.Bot.Firehose.start_link([
    name: :my_bot_firehose,
    server_pid: self(),
    cursor: 32_625_482_169
  ])
  ```
  """

  use GenServer

  alias ProtoRune.Bot.Firehose.State
  alias ProtoRune.Firehose
  alias ProtoRune.Firehose.Event

  @type option ::
          {:name, atom}
          | {:relay, String.t()}
          | {:cursor, String.t() | non_neg_integer}
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
  Returns the sequence number of the last delivered event, or `nil` when no event
  has been delivered yet. Feed it back as the `:cursor` option to backfill from
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
      transport_opts: state.transport_opts
    ]

    opts = if state.cursor, do: Keyword.put(opts, :cursor, state.cursor), else: opts

    {:ok, pid} = Firehose.start_link(opts)
    {:noreply, %{state | firehose: pid}}
  end

  @impl true
  def handle_call(:cursor, _from, %State{firehose: nil} = state) do
    {:reply, state.cursor, state}
  end

  def handle_call(:cursor, _from, %State{firehose: pid} = state) do
    {:reply, Firehose.cursor(pid), state}
  end

  @impl true
  def handle_info({:firehose, %Event{} = event}, %State{} = state) do
    dispatch_event(state, event)
    {:noreply, state}
  end

  def handle_info(_message, %State{firehose: nil} = state) do
    {:noreply, state}
  end

  def handle_info(message, %State{firehose: pid} = state) do
    send(pid, message)
    {:noreply, state}
  end

  @impl true
  def format_status({:state, state}) do
    {:state, Map.take(state, [:name, :relay, :cursor, :auto_reconnect])}
  end

  def format_status(key), do: key

  defp dispatch_event(%State{} = state, %Event{type: :commit} = event) do
    for op <- event.ops do
      record = if op.cid, do: Map.get(event.blocks, to_string(op.cid))

      send(
        state.server_pid,
        {:handle_event, :commit,
         %{
           repo: event.repo,
           rev: event.rev,
           seq: event.seq,
           time: event.time,
           action: op.action,
           path: op.path,
           cid: op.cid,
           record: record
         }}
      )
    end
  end

  defp dispatch_event(%State{} = state, %Event{type: type} = event) do
    send(
      state.server_pid,
      {:handle_event, type, %{repo: event.repo, seq: event.seq, time: event.time, payload: event.payload}}
    )
  end
end
