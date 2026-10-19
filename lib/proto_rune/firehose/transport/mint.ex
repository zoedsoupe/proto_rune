defmodule ProtoRune.Firehose.Transport.Mint do
  @moduledoc """
  `ProtoRune.Firehose.Transport` implementation backed by `Mint` and
  `Mint.WebSocket`.

  Unlike gun, Mint manages nothing: this module owns the receive loop (the
  caller's process receives the raw socket messages, which `stream/2`
  translates), answers pings with pongs, and relies on
  `Mint.WebSocket.decode/2` to reassemble fragmented messages. The
  connection is in active mode, so no explicit recv loop runs: the socket
  messages arrive in the connection owner's mailbox and flow through
  `ProtoRune.StreamClient`'s `handle_info` into `stream/2`.

  Frames sent while the HTTP 101 upgrade response is still being parsed
  (the same TCP packet) are consumed by Mint's HTTP parser and dropped;
  relays send frames in separate packets after completing the handshake,
  so this has not been observed in practice.

  TLS peer verification is Mint's default (`verify: :verify_peer` with the
  OTP certificate store).
  """

  @behaviour ProtoRune.Firehose.Transport

  defstruct [:conn, :ref, :websocket]

  @connect_timeout 5_000

  @impl true
  def connect(url, opts) do
    uri = URI.parse(url)
    timeout = Keyword.get(opts, :timeout, @connect_timeout)
    scheme = if uri.scheme == "ws", do: :http, else: :https
    ws_scheme = if uri.scheme == "ws", do: :ws, else: :wss
    port = uri.port || if(scheme == :https, do: 443, else: 80)
    path = if uri.query, do: "#{uri.path || "/"}?#{uri.query}", else: uri.path || "/"

    connect_opts = [
      protocols: [:http1],
      timeout: timeout,
      transport_opts: Keyword.get(opts, :transport_opts, [])
    ]

    with {:ok, conn} <- Mint.HTTP.connect(scheme, uri.host, port, connect_opts),
         {:ok, conn, ref, websocket} <- upgrade(ws_scheme, conn, path, timeout) do
      {:ok, %__MODULE__{conn: conn, ref: ref, websocket: websocket}}
    else
      {:error, %Mint.HTTP1{} = conn, reason} ->
        Mint.HTTP.close(conn)
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # The upgrade request goes out with Mint.WebSocket.upgrade/4; the 101
  # reply is assembled from the active-mode messages the caller receives
  # until the response completes.
  defp upgrade(ws_scheme, conn, path, timeout) do
    case Mint.WebSocket.upgrade(ws_scheme, conn, path, []) do
      {:ok, conn, ref} -> await_upgrade(conn, ref, [], timeout)
      {:error, conn, reason} -> {:error, conn, reason}
    end
  end

  defp await_upgrade(conn, ref, acc, timeout) do
    receive do
      message ->
        case Mint.WebSocket.stream(conn, message) do
          {:ok, conn, responses} ->
            acc = acc ++ responses

            if Enum.any?(acc, &match?({:done, ^ref}, &1)) do
              finish_upgrade(conn, ref, acc)
            else
              await_upgrade(conn, ref, acc, timeout)
            end

          {:error, conn, reason, _responses} ->
            {:error, conn, reason}

          :unknown ->
            await_upgrade(conn, ref, acc, timeout)
        end
    after
      timeout -> {:error, conn, :timeout}
    end
  end

  defp finish_upgrade(conn, ref, acc) do
    {:status, ^ref, status} = Enum.find(acc, &match?({:status, ^ref, _}, &1))
    {:headers, ^ref, headers} = Enum.find(acc, &match?({:headers, ^ref, _}, &1))

    case Mint.WebSocket.new(conn, ref, status, headers) do
      {:ok, conn, websocket} ->
        {:ok, conn, ref, websocket}

      {:error, conn, reason} ->
        {:error, conn, {:ws_upgrade_failed, reason}}
    end
  end

  @impl true
  def stream(%__MODULE__{} = conn, message) do
    case Mint.WebSocket.stream(conn.conn, message) do
      {:ok, mint_conn, responses} ->
        handle_responses(%{conn | conn: mint_conn}, responses, [])

      {:error, mint_conn, reason, _responses} ->
        {:error, %{conn | conn: mint_conn}, reason}

      :unknown ->
        :unknown
    end
  end

  defp handle_responses(conn, [], acc), do: {:ok, conn, Enum.reverse(acc)}

  defp handle_responses(conn, [{:data, ref, data} | rest], acc) when ref == conn.ref do
    case Mint.WebSocket.decode(conn.websocket, data) do
      {:ok, websocket, frames} ->
        case handle_frames(%{conn | websocket: websocket}, frames, acc) do
          {:ok, conn, acc} -> handle_responses(conn, rest, acc)
          {:error, conn, reason} -> {:error, conn, reason}
        end

      {:error, websocket, reason} ->
        {:error, %{conn | websocket: websocket}, reason}
    end
  end

  defp handle_responses(conn, [_other | rest], acc), do: handle_responses(conn, rest, acc)

  # Frames arrive already reassembled. Pings must be answered with pongs
  # (Mint does not do it), pongs and strays are dropped, a close ends the
  # stream with a `:closed` frame like gun's `{:gun_ws, ..., :close}` did.
  defp handle_frames(conn, [], acc), do: {:ok, conn, acc}

  defp handle_frames(conn, [frame | rest], acc) do
    case handle_frame(conn, frame) do
      {:deliver, conn, frame} -> handle_frames(conn, rest, [frame | acc])
      {:skip, conn} -> handle_frames(conn, rest, acc)
      {:closed, conn} -> {:ok, conn, [:closed | acc]}
      {:error, conn, reason} -> {:error, conn, reason}
    end
  end

  defp handle_frame(conn, {:ping, data}), do: reply_to_ping(conn, {:pong, data})
  defp handle_frame(conn, :ping), do: reply_to_ping(conn, :pong)
  defp handle_frame(conn, {:pong, _data}), do: {:skip, conn}
  defp handle_frame(conn, :pong), do: {:skip, conn}
  defp handle_frame(conn, {:binary, data}), do: {:deliver, conn, {:binary, data}}
  defp handle_frame(conn, {:text, data}), do: {:deliver, conn, {:text, data}}
  defp handle_frame(conn, :close), do: close_frame(conn)
  defp handle_frame(conn, {:close, _code, _reason}), do: close_frame(conn)
  defp handle_frame(conn, {:error, reason}), do: {:error, conn, reason}

  defp reply_to_ping(conn, pong) do
    case send_frame(conn, pong) do
      {:ok, conn} -> {:skip, conn}
      {:error, conn, reason} -> {:error, conn, reason}
    end
  end

  defp close_frame(conn) do
    ack_close(conn)
    {:closed, conn}
  end

  defp send_frame(conn, frame) do
    case Mint.WebSocket.encode(conn.websocket, frame) do
      {:ok, websocket, data} ->
        case Mint.WebSocket.stream_request_body(conn.conn, conn.ref, data) do
          {:ok, mint_conn} -> {:ok, %{conn | websocket: websocket, conn: mint_conn}}
          {:error, mint_conn, reason} -> {:error, %{conn | conn: mint_conn}, reason}
        end

      {:error, websocket, reason} ->
        {:error, %{conn | websocket: websocket}, reason}
    end
  end

  # Echo the close frame so the peer does not wait for it; the socket itself
  # is torn down by close/1 (or the reconnect path).
  defp ack_close(conn) do
    case Mint.WebSocket.encode(conn.websocket, :close) do
      {:ok, _websocket, data} ->
        _ = Mint.WebSocket.stream_request_body(conn.conn, conn.ref, data)
        :ok

      {:error, _websocket, _reason} ->
        :ok
    end
  end

  @impl true
  def close(%__MODULE__{} = conn) do
    # Best-effort close frame; the point of close/1 is the socket going away.
    case Mint.WebSocket.encode(conn.websocket, :close) do
      {:ok, _websocket, data} ->
        _ = Mint.WebSocket.stream_request_body(conn.conn, conn.ref, data)

      {:error, _websocket, _reason} ->
        :ok
    end

    Mint.HTTP.close(conn.conn)
    :ok
  end
end
