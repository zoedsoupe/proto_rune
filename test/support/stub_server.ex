defmodule ProtoRune.StubServer do
  @moduledoc """
  Minimal dependency-free HTTP server for tests: routes are registered by
  method and path and answer with canned responses.

  Handlers receive the parsed request and return `{status, headers, body}`:

      StubServer.expect_once(server, "POST", "/json", fn req ->
        assert ["application/json"] = req.headers["content-type"]
        assert %{"hello" => "world"} = JSON.decode!(req.body)
        {200, [{"content-type", "application/json"}], ~s|{"ok":true}|}
      end)

  The request handed to handlers looks like:

      %{
        method: "POST",
        path: "/xrpc/com.atproto.server.createSession",
        query: %{"cursor" => "page2"},
        headers: %{"content-type" => ["application/json"]},
        body: <<...>>
      }
  """

  @recv_timeout 15_000

  @doc """
  Opens a server on an ephemeral 127.0.0.1 port. The listener is linked to
  the test process, so a crashing handler fails the test, and it is killed
  when the test exits.
  """
  def open do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, port} = :inet.port(listen)
    routes = :ets.new(:stub_routes, [:set, :public])
    pid = spawn_link(fn -> accept_loop(listen, routes) end)

    ExUnit.Callbacks.on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {:ok, %{port: port, url: "http://localhost:#{port}", pid: pid, listener: listen, routes: routes}}
  end

  @doc "Registers a route served on every request."
  def expect(server, method, path, handler) do
    :ets.insert(server.routes, {{:repeat, method, path}, handler})
    :ok
  end

  @doc "Registers a route consumed by its first request."
  def expect_once(server, method, path, handler) do
    :ets.insert(server.routes, {{method, path}, handler})
    :ok
  end

  @doc "Registers a route that accepts the request and never responds."
  def hang(server, method, path) do
    :ets.insert(server.routes, {{:hang, method, path}, :hang})
    :ok
  end

  @doc "Stops the listener so further connections are refused."
  def down(server), do: :gen_tcp.close(server.listener)

  defp accept_loop(listen, routes) do
    case :gen_tcp.accept(listen, :infinity) do
      {:ok, sock} ->
        serve(sock, routes)
        :gen_tcp.close(sock)
        accept_loop(listen, routes)

      {:error, reason} when reason in [:closed, :einval] ->
        :ok

      {:error, reason} ->
        exit({:stub_server, {:accept, reason}})
    end
  end

  defp serve(sock, routes) do
    {head, buffer} = recv_head(sock, "")
    %{headers: headers, method: method, path: path, query: query} = parse_head(head)
    body = read_body(sock, buffer, content_length(headers))
    dispatch(sock, routes, %{method: method, path: path, query: query, headers: headers, body: body})
  end

  defp recv_head(sock, buffer) do
    case :binary.split(buffer, "\r\n\r\n") do
      [head, rest] ->
        {head, rest}

      [_partial] ->
        case :gen_tcp.recv(sock, 0, @recv_timeout) do
          {:ok, data} -> recv_head(sock, buffer <> data)
          {:error, reason} -> exit({:stub_server, {:recv_head, reason}})
        end
    end
  end

  defp parse_head(head) do
    [request_line | header_lines] = String.split(head, "\r\n")
    [method, target | _rest] = String.split(request_line, " ")

    {path, query_string} =
      case String.split(target, "?", parts: 2) do
        [path] -> {path, ""}
        [path, query] -> {path, query}
      end

    %{
      method: method,
      path: path,
      query: URI.decode_query(query_string),
      headers: parse_headers(header_lines)
    }
  end

  defp parse_headers(lines) do
    Enum.reduce(lines, %{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          name = String.downcase(name)
          Map.update(acc, name, [String.trim(value)], &(&1 ++ [String.trim(value)]))

        [_not_a_header] ->
          acc
      end
    end)
  end

  defp content_length(headers) do
    case headers["content-length"] do
      [value | _rest] -> String.to_integer(value)
      nil -> 0
    end
  end

  defp read_body(_sock, buffer, length) when byte_size(buffer) >= length do
    <<body::binary-size(^length), _overflow::binary>> = buffer
    body
  end

  defp read_body(sock, buffer, length) do
    case :gen_tcp.recv(sock, length - byte_size(buffer), @recv_timeout) do
      {:ok, data} -> buffer <> data
      {:error, reason} -> exit({:stub_server, {:recv_body, reason}})
    end
  end

  defp dispatch(sock, routes, request) do
    case :ets.take(routes, {request.method, request.path}) do
      [{_key, handler}] -> respond_with(sock, handler, request)
      [] -> dispatch_repeatable(sock, routes, request)
    end
  end

  defp dispatch_repeatable(sock, routes, request) do
    case :ets.lookup(routes, {:repeat, request.method, request.path}) do
      [{_key, handler}] -> respond_with(sock, handler, request)
      [] -> dispatch_hang(sock, routes, request)
    end
  end

  defp dispatch_hang(sock, routes, request) do
    case :ets.lookup(routes, {:hang, request.method, request.path}) do
      [{_key, :hang}] -> Process.sleep(:infinity)
      [] -> respond(sock, 500, [], "no route for #{request.method} #{request.path}")
    end
  end

  defp respond_with(sock, handler, request) do
    {status, headers, body} = handler.(request)
    respond(sock, status, headers, body)
  end

  defp respond(sock, status, headers, body) do
    headers = [{"content-length", Integer.to_string(byte_size(body))}, {"connection", "close"} | headers]
    head = Enum.map_join(headers, "", fn {name, value} -> "#{name}: #{value}\r\n" end)
    :gen_tcp.send(sock, ["HTTP/1.1 #{status} #{reason(status)}\r\n", head, "\r\n", body])
  end

  defp reason(200), do: "OK"
  defp reason(500), do: "Internal Server Error"
  defp reason(_status), do: "Status"
end
