defmodule ProtoRune.Firehose.Transport.MintTest do
  @moduledoc """
  Exercises `ProtoRune.Firehose.Transport.Mint` against a minimal local
  WebSocket server: real TCP handshake, frames, ping/pong and close, no
  network and no TLS.
  """

  use ExUnit.Case, async: true

  alias ProtoRune.Firehose.Transport.Mint

  @ws_guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  setup do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, port} = :inet.port(listen)
    parent = self()

    server =
      spawn_link(fn ->
        {:ok, sock} = :gen_tcp.accept(listen, 5_000)
        {:ok, request} = :gen_tcp.recv(sock, 0, 5_000)
        :gen_tcp.send(sock, upgrade_response(request))
        ws_server(parent, sock)
      end)

    {:ok, port: port, server: server}
  end

  test "connects, delivers text and binary frames, answers pings, sees close", %{port: port, server: server} do
    assert {:ok, conn} = Mint.connect("ws://127.0.0.1:#{port}/xrpc/subscribe", [])

    # a text frame from the server decodes as a transport frame
    send_frame(server, {:text, ~s|{"x":1}|})
    assert_receive {:tcp, sock, data}, 1_000
    assert {:ok, _conn, [{:text, ~s|{"x":1}|}]} = Mint.stream(conn, {:tcp, sock, data})

    # a binary frame decodes as well
    send_frame(server, {:binary, <<1, 2, 3>>})
    assert_receive {:tcp, sock, data}, 1_000
    assert {:ok, _conn, [{:binary, <<1, 2, 3>>}]} = Mint.stream(conn, {:tcp, sock, data})

    # pings are answered with pongs before the caller sees any frame
    send_frame(server, :ping)
    assert_receive {:tcp, sock, data}, 1_000
    assert {:ok, _conn, []} = Mint.stream(conn, {:tcp, sock, data})
    assert pong_received?(server)

    # a close frame surfaces as :closed
    send_frame(server, {:close, 1000, ""})
    assert_receive {:tcp, sock, data}, 1_000
    assert {:ok, _conn, [:closed]} = Mint.stream(conn, {:tcp, sock, data})

    assert :ok = Mint.close(conn)
  end

  test "messages the transport does not own are :unknown", %{port: port} do
    assert {:ok, conn} = Mint.connect("ws://127.0.0.1:#{port}/xrpc/subscribe", [])
    assert :unknown = Mint.stream(conn, {:some_other_message, :nope})
    Mint.close(conn)
  end

  # -- minimal ws server -----------------------------------------------------

  defp ws_server(parent, sock) do
    receive do
      {:send_frame, frame} ->
        :ok = :gen_tcp.send(sock, encode_frame(frame))

        case frame do
          {:close, _code, _reason} -> :ok
          _other -> ws_server(parent, sock)
        end

      {:assert_pong, reply_to} ->
        {:ok, pong} = :gen_tcp.recv(sock, 0, 5_000)
        send(reply_to, {:pong, pong})
        ws_server(parent, sock)

      :stop ->
        :gen_tcp.close(sock)
    end
  end

  defp send_frame(server, frame) do
    send(server, {:send_frame, frame})
  end

  defp pong_received?(server) do
    send(server, {:assert_pong, self()})

    receive do
      {:pong, <<0x8A, _rest::binary>>} -> true
      {:pong, other} -> flunk("expected a pong frame, got: #{inspect(other)}")
    after
      1_000 -> flunk("no pong received")
    end
  end

  defp encode_frame({:text, data}), do: unmasked_frame(0x1, data)
  defp encode_frame({:binary, data}), do: unmasked_frame(0x2, data)
  defp encode_frame(:ping), do: unmasked_frame(0x9, <<>>)
  defp encode_frame({:close, code, reason}), do: unmasked_frame(0x8, <<code::16, reason::binary>>)

  # server-to-client frames are unmasked; lengths below 126 fit one byte
  defp unmasked_frame(opcode, payload) do
    <<1::size(1), 0::size(3), opcode::size(4), 0::size(1), byte_size(payload)::size(7), payload::binary>>
  end

  defp upgrade_response(request) do
    # Mint sends header names downcased; String.split drops the delimiter
    [_before, rest] = String.split(request, "sec-websocket-key: ")
    [key | _] = String.split(rest, "\r\n")

    accept =
      :sha
      |> :crypto.hash(key <> @ws_guid)
      |> Base.encode64()

    "HTTP/1.1 101 Switching Protocols\r\n" <>
      "Upgrade: websocket\r\n" <>
      "Connection: Upgrade\r\n" <>
      "Sec-WebSocket-Accept: #{accept}\r\n" <>
      "\r\n"
  end
end
