defmodule ProtoRune.Jetstream do
  @moduledoc """
  Consumer for the AT Protocol Jetstream, the filtered JSON re-encode of
  the repo firehose.

  Where `ProtoRune.Firehose` delivers every commit on the network and
  decodes every CAR block locally, Jetstream applies `wantedCollections`
  and `wantedDids` filters server-side and ships plain JSON text frames:
  a consumer that only cares about a handful of collections receives (and
  pays to decode) only those events. Add it to your supervision tree:

      children = [
        {ProtoRune.Jetstream,
         handler: MyConsumer, wanted_collections: ["place.quintal.feed.prosa"]}
      ]

  or start it directly with `start_link/1`.

  ## Handlers

  The required `:handler` option tells the consumer where events go:

    * a pid, which receives `{:jetstream, %ProtoRune.Jetstream.Event{}}` messages
    * a one-arity function, called with the event
    * a `{module, function}` tuple, called as `function.(event)`

  ## Filtering and cursors

    * `:wanted_collections` - AT-URI collections to receive commit events
      for (repeatable server-side filter). Identity and account events
      are not collection-scoped and always flow through.
    * `:wanted_dids` - restrict events to these repository DIDs.
    * `:cursor` - a `time_us` timestamp (microseconds) to resume from.
      Jetstream keeps a rolling playback window; resuming may re-deliver
      a handful of events around the cursor, so consumers must stay
      idempotent. When the connection drops, the consumer reconnects
      resuming from the last delivered `time_us`. `cursor/1` returns the
      current value, e.g. to persist it for a later restart.

  ## Remaining options

    * `:relay` - the Jetstream instance base URL
      (default: `"wss://jetstream2.us-east.bsky.network"`).
    * `:auto_reconnect` - reconnect automatically on connection loss
      (default: `true`). When `false`, the process stops with reason
      `{:jetstream_disconnected, reason}` instead.
    * `:backoff_initial` / `:backoff_max` - reconnect backoff bounds in
      milliseconds (default: `1_000` / `30_000`). The delay doubles after
      each failed attempt and resets once connected.
    * `:transport` - the `ProtoRune.Firehose.Transport` implementation to
      use (default: `ProtoRune.Firehose.Transport.Gun`). Jetstream speaks
      the same WebSocket transport as the firehose, only with text frames.
    * `:transport_opts` - options passed to the transport.
    * `:name` - registers the process under the given name.
  """

  use GenServer

  import Peri

  alias ProtoRune.Jetstream.Event

  require Logger

  @default_relay "wss://jetstream2.us-east.bsky.network"
  @subscribe_path "/subscribe"

  @typedoc "Where decoded events are delivered to."
  @type handler :: pid | (Event.t() -> term) | {module, atom}

  defschema(:options_t, %{
    name: :atom,
    relay: {:string, {:default, @default_relay}},
    cursor: :integer,
    wanted_collections: {{:list, :string}, {:default, []}},
    wanted_dids: {{:list, :string}, {:default, []}},
    handler: {:required, :any},
    auto_reconnect: {:boolean, {:default, true}},
    backoff_initial: {:integer, {:default, 1_000}},
    backoff_max: {:integer, {:default, 30_000}},
    transport: {:atom, {:default, ProtoRune.Firehose.Transport.Gun}},
    transport_opts: {:any, {:default, []}}
  })

  @doc """
  Starts a Jetstream consumer process.

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
  Returns the `time_us` of the last delivered event, or `nil` when no
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
        Logger.info("[#{__MODULE__}] ==> Connected to jetstream at #{state.relay}")
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
      {:text, data}, {:ok, state} ->
        {:cont, {:ok, process_frame(state, data)}}

      # binary frames belong to the CBOR firehose, jetstream speaks JSON text
      {:binary, _data}, {:ok, state} ->
        {:cont, {:ok, state}}

      :closed, {:ok, state} ->
        {:halt, {:disconnect, :closed, state}}
    end)
    |> case do
      {:ok, state} -> {:noreply, state}
      {:disconnect, reason, state} -> reconnect(reason, state)
    end
  end

  defp process_frame(state, data) do
    with {:ok, message} <- JSON.decode(data),
         {:ok, %Event{} = event} <- Event.from_message(message) do
      deliver(state.handler, event)
      %{state | cursor: event.time_us || state.cursor}
    else
      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] ==> Dropped undecodable jetstream message: #{inspect(reason)}")
        state
    end
  end

  defp reconnect(reason, state) do
    if state.auto_reconnect do
      Logger.warning(
        "[#{__MODULE__}] ==> Jetstream connection lost (#{inspect(reason)}), reconnecting in #{state.backoff}ms"
      )

      Process.send_after(self(), :reconnect, state.backoff)
      {:noreply, %{state | conn: nil, backoff: min(state.backoff * 2, state.backoff_max)}}
    else
      {:stop, {:jetstream_disconnected, reason}, state}
    end
  end

  defp stream_url(state) do
    params =
      Enum.map(state.wanted_collections, &{"wantedCollections", &1}) ++
        Enum.map(state.wanted_dids, &{"wantedDids", &1})

    params = if state.cursor, do: params ++ [{"cursor", Integer.to_string(state.cursor)}], else: params

    url = String.trim_trailing(state.relay, "/") <> @subscribe_path
    if params == [], do: url, else: url <> "?" <> URI.encode_query(params)
  end

  defp deliver(handler, event) when is_pid(handler), do: send(handler, {:jetstream, event})
  defp deliver(handler, event) when is_function(handler, 1), do: handler.(event)
  defp deliver({module, function}, event), do: apply(module, function, [event])
end
