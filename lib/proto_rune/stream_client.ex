defmodule ProtoRune.StreamClient do
  @moduledoc false

  # Shared WebSocket consumer backing `ProtoRune.Firehose` and
  # `ProtoRune.Jetstream`. The two streams differ only in how they build
  # the subscribe URL, which frame kind they speak and how a frame decodes
  # into an event; connection lifecycle, backoff, cursor tracking and
  # handler delivery live here.
  #
  # Config keys:
  #
  #   * `:handler` - pid, one-arity function or `{module, function}`
  #   * `:url_fun` - `(cursor :: integer | nil -> String.t())`
  #   * `:frame` - `:binary` (CBOR firehose) or `:text` (JSON jetstream)
  #   * `:decode_fun` - `(binary -> {:ok, event, cursor | nil} | {:error, term})`
  #   * `:tag` - message tag for pid handlers (`:firehose` | `:jetstream`)
  #   * `:label` - log label (e.g. "firehose at wss://bsky.network")
  #   * `:cursor` - initial cursor, `nil` for live
  #   * `:auto_reconnect`, `:backoff_initial`, `:backoff_max`
  #   * `:transport`, `:transport_opts`
  #   * `:stop_reason` - atom head of the stop reason when
  #     `:auto_reconnect` is false (e.g. `:firehose_disconnected`)

  use GenServer

  require Logger

  def start_link(config, gen_opts \\ []) do
    GenServer.start_link(__MODULE__, config, gen_opts)
  end

  def cursor(server), do: GenServer.call(server, :cursor)

  @impl true
  def init(config) do
    state =
      config
      |> Map.put_new(:cursor, nil)
      |> Map.put(:conn, nil)
      |> Map.put(:backoff, config.backoff_initial)

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case state.transport.connect(state.url_fun.(state.cursor), state.transport_opts) do
      {:ok, conn} ->
        Logger.info("[#{__MODULE__}] ==> Connected to #{state.label}")
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
      {frame_kind, data}, {:ok, state} when frame_kind == state.frame ->
        {:cont, {:ok, process_frame(state, data)}}

      # the other stream's frame kind never arrives here; ignore strays
      {_kind, _data}, {:ok, state} ->
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
    case state.decode_fun.(data) do
      {:ok, event, cursor} ->
        deliver(state.handler, state.tag, event)
        %{state | cursor: cursor || state.cursor}

      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] ==> Dropped undecodable #{state.tag} frame: #{inspect(reason)}")
        state
    end
  end

  defp reconnect(reason, state) do
    if state.auto_reconnect do
      Logger.warning(
        "[#{__MODULE__}] ==> #{state.label} connection lost (#{inspect(reason)}), reconnecting in #{state.backoff}ms"
      )

      Process.send_after(self(), :reconnect, state.backoff)
      {:noreply, %{state | conn: nil, backoff: min(state.backoff * 2, state.backoff_max)}}
    else
      {:stop, {state.stop_reason, reason}, state}
    end
  end

  defp deliver(handler, tag, event) when is_pid(handler), do: send(handler, {tag, event})
  defp deliver(handler, _tag, event) when is_function(handler, 1), do: handler.(event)
  defp deliver({module, function}, _tag, event), do: apply(module, function, [event])
end
