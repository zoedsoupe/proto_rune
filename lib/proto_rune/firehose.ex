defmodule ProtoRune.Firehose do
  @moduledoc """
  Real-time event stream client for the ATProto firehose.

  Connects to `com.atproto.sync.subscribeRepos` over WebSocket, decodes the
  CBOR frames and delivers each event as a `ProtoRune.Firehose.Event` to a
  consumer-provided handler.

  ProtoRune is a library and starts no processes on its own: add the
  firehose to your own supervision tree:

      children = [
        {ProtoRune.Firehose, handler: self()}
      ]

  or start it directly with `start_link/1`.

  ## Handlers

  The required `:handler` option tells the client where events go:

    * a pid, which receives `{:firehose, %ProtoRune.Firehose.Event{}}` messages
    * a one-arity function, called with the event
    * a `{module, function}` tuple, called as `function.(event)`

  ## Backfill and cursors

  Every event carries a sequence number in `event.seq`. Pass a previously
  seen sequence number as the `:cursor` option to backfill events missed
  while disconnected (relays keep a rolling history window). When the
  connection drops, the client reconnects automatically resuming from the
  last delivered sequence number. `cursor/1` returns the current sequence
  number, e.g. to persist it for a later restart.

  ## Options

    * `:handler` (required) - where events are delivered (see above).
    * `:relay` - the relay base URL (default: `"wss://bsky.network"`).
    * `:cursor` - sequence number to start the stream from (default: live).
    * `:auto_reconnect` - reconnect automatically on connection loss
      (default: `true`). When `false`, the process stops with reason
      `{:firehose_disconnected, reason}` instead.
    * `:backoff_initial` / `:backoff_max` - reconnect backoff bounds in
      milliseconds (default: `1_000` / `30_000`). The delay doubles after
      each failed attempt and resets once connected.
    * `:transport` - the `ProtoRune.Firehose.Transport` implementation to
      use (default: `ProtoRune.Firehose.Transport.Gun`).
    * `:transport_opts` - options passed to the transport, e.g.
      `[timeout: 10_000]`.
    * `:name` - registers the process under the given name.

  ## Examples

      defmodule MyConsumer do
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(_opts) do
          {:ok, firehose} = ProtoRune.Firehose.start_link(handler: self())
          {:ok, %{firehose: firehose}}
        end

        def handle_info({:firehose, %ProtoRune.Firehose.Event{type: :commit} = event}, state) do
          Enum.each(event.ops, &process_op(event, &1))
          {:noreply, state}
        end

        def handle_info({:firehose, _event}, state), do: {:noreply, state}
      end
  """

  use GenServer

  import Peri

  alias ProtoRune.Firehose.Event
  alias ProtoRune.Firehose.Frame

  require Logger

  @default_relay "wss://bsky.network"
  @subscribe_path "/xrpc/com.atproto.sync.subscribeRepos"

  @typedoc "Where decoded events are delivered to."
  @type handler :: pid | (Event.t() -> term) | {module, atom}

  defschema(:options_t, %{
    name: :atom,
    relay: {:string, {:default, @default_relay}},
    cursor: :integer,
    handler: {:required, :any},
    auto_reconnect: {:boolean, {:default, true}},
    backoff_initial: {:integer, {:default, 1_000}},
    backoff_max: {:integer, {:default, 30_000}},
    transport: {:atom, {:default, ProtoRune.Firehose.Transport.Gun}},
    transport_opts: {:any, {:default, []}}
  })

  @doc """
  Starts a firehose client process.

  See the module documentation for the available options.
  """
  @spec start_link(keyword | map) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    data = options_t!(opts)

    case validate_handler(data[:handler]) do
      :ok -> GenServer.start_link(__MODULE__, data, start_opts(data))
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the sequence number of the last delivered event, or `nil` when no
  event has been delivered yet.
  """
  @spec cursor(GenServer.server()) :: non_neg_integer | nil
  def cursor(server), do: GenServer.call(server, :cursor)

  defp start_opts(data) do
    case Map.get(data, :name) do
      nil -> []
      name -> [name: name]
    end
  end

  defp validate_handler(handler) when is_pid(handler), do: :ok
  defp validate_handler(handler) when is_function(handler, 1), do: :ok
  defp validate_handler({module, function}) when is_atom(module) and is_atom(function), do: :ok
  defp validate_handler(_other), do: {:error, :invalid_handler}

  @impl true
  def init(data) do
    state =
      data
      |> Map.put_new(:cursor, nil)
      |> Map.put(:conn, nil)
      |> Map.put(:backoff, data[:backoff_initial])

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case state.transport.connect(stream_url(state), state.transport_opts) do
      {:ok, conn} ->
        Logger.info("[#{__MODULE__}] ==> Connected to firehose at #{state.relay}")
        {:noreply, %{state | conn: conn, backoff: state.backoff_initial}}

      {:error, reason} ->
        reconnect({:connect_failed, reason}, state)
    end
  end

  @impl true
  def handle_call(:cursor, _from, state), do: {:reply, state.cursor, state}

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info(_message, %{conn: nil} = state) do
    {:noreply, state}
  end

  def handle_info(message, state) do
    case state.transport.stream(state.conn, message) do
      :unknown ->
        {:noreply, state}

      {:ok, conn, frames} ->
        state
        |> Map.put(:conn, conn)
        |> process_frames(frames)

      {:error, conn, reason} ->
        reconnect(reason, %{state | conn: conn})
    end
  end

  @impl true
  def terminate(_reason, %{conn: nil}), do: :ok
  def terminate(_reason, %{conn: conn, transport: transport}), do: transport.close(conn)

  defp process_frames(state, frames) do
    frames
    |> Enum.reduce_while({:ok, state}, fn
      {:binary, data}, {:ok, state} ->
        {:cont, {:ok, process_frame(state, data)}}

      :closed, {:ok, state} ->
        {:halt, {:disconnect, :closed, state}}
    end)
    |> case do
      {:ok, state} -> {:noreply, state}
      {:disconnect, reason, state} -> reconnect(reason, state)
    end
  end

  defp process_frame(state, data) do
    case Frame.decode(data) do
      {:ok, %Event{} = event} ->
        deliver(state.handler, event)
        %{state | cursor: event.seq || state.cursor}

      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] ==> Dropped undecodable firehose frame: #{inspect(reason)}")
        state
    end
  end

  defp reconnect(reason, state) do
    if state.auto_reconnect do
      Logger.warning(
        "[#{__MODULE__}] ==> Firehose connection lost (#{inspect(reason)}), reconnecting in #{state.backoff}ms"
      )

      Process.send_after(self(), :reconnect, state.backoff)
      {:noreply, %{state | conn: nil, backoff: min(state.backoff * 2, state.backoff_max)}}
    else
      {:stop, {:firehose_disconnected, reason}, state}
    end
  end

  defp stream_url(state) do
    url = String.trim_trailing(state.relay, "/") <> @subscribe_path
    if state.cursor, do: "#{url}?cursor=#{state.cursor}", else: url
  end

  defp deliver(handler, event) when is_pid(handler), do: send(handler, {:firehose, event})
  defp deliver(handler, event) when is_function(handler, 1), do: handler.(event)
  defp deliver({module, function}, event), do: apply(module, function, [event])
end
