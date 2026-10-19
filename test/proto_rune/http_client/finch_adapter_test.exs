defmodule ProtoRune.HTTPClient.Adapters.FinchTest do
  @moduledoc """
  Feature-parity tests for the Finch adapter against a real HTTP server
  (Bypass), exercising the `ProtoRune.Finch` pool end to end.
  """

  use ProtoRune.TestCase, async: true

  import Plug.Conn

  alias ProtoRune.HTTPClient
  alias ProtoRune.HTTPClient.Adapters.Finch, as: FinchAdapter

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, url: "http://localhost:#{bypass.port}"}
  end

  test "sends json: bodies with the application/json content type", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "POST", "/json", fn conn ->
      assert get_req_header(conn, "content-type") == ["application/json"]
      {:ok, body, conn} = read_body(conn)
      assert JSON.decode!(body) == %{"hello" => "world"}
      conn |> put_resp_content_type("application/json") |> resp(200, ~s|{"ok":true}|)
    end)

    assert {:ok, %{status: 200, body: ~s|{"ok":true}|}} =
             FinchAdapter.request(:post, url <> "/json", json: %{hello: "world"})
  end

  test "sends form: bodies urlencoded with the form content type", %{bypass: bypass, url: url} do
    form = %{"grant_type" => "authorization_code", "code" => "abc 123"}

    Bypass.expect_once(bypass, "POST", "/token", fn conn ->
      assert get_req_header(conn, "content-type") == ["application/x-www-form-urlencoded"]
      {:ok, body, conn} = read_body(conn)
      assert body == URI.encode_query(form)
      resp(conn, 200, "ok")
    end)

    assert {:ok, %{status: 200}} = FinchAdapter.request(:post, url <> "/token", form: form)
  end

  test "sends raw body: with the caller's content type", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "POST", "/blob", fn conn ->
      assert get_req_header(conn, "content-type") == ["image/png"]
      {:ok, body, conn} = read_body(conn)
      assert body == <<1, 2, 3>>
      resp(conn, 200, "ok")
    end)

    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:post, url <> "/blob",
               body: <<1, 2, 3>>,
               headers: [{"content-type", "image/png"}]
             )
  end

  test "passes headers: through and asks for identity encoding", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "GET", "/xrpc/test", fn conn ->
      assert get_req_header(conn, "accept-encoding") == ["identity"]
      assert get_req_header(conn, "x-custom") == ["value"]
      resp(conn, 200, "ok")
    end)

    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:get, url <> "/xrpc/test", headers: [{"x-custom", "value"}])
  end

  test "honors a caller-provided accept-encoding over identity", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "GET", "/xrpc/test", fn conn ->
      assert get_req_header(conn, "accept-encoding") == ["gzip"]
      resp(conn, 200, "ok")
    end)

    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:get, url <> "/xrpc/test", headers: [{"accept-encoding", "gzip"}])
  end

  test "returns response headers as a list of tuples and raw bodies", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "GET", "/xrpc/test", fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> resp(200, ~s|{"a":1}|)
    end)

    {:ok, %{status: 200, headers: headers, body: body}} =
      FinchAdapter.request(:get, url <> "/xrpc/test", [])

    assert is_list(headers)
    assert {"content-type", value} = List.keyfind(headers, "content-type", 0)
    assert String.starts_with?(value, "application/json")
    assert body == ~s|{"a":1}|

    assert HTTPClient.get_header(headers, "content-type") == value
  end

  test "accepts :timeout as a receive deadline", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "GET", "/xrpc/test", fn conn ->
      resp(conn, 200, "ok")
    end)

    # Pins that :timeout maps to Finch's :receive_timeout; Bypass cannot
    # assert the receive path itself without racing the client disconnect.
    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:get, url <> "/xrpc/test", timeout: 5_000)
  end

  test "connection errors are {:error, reason} without raising", %{bypass: bypass, url: url} do
    Bypass.down(bypass)

    assert {:error, _reason} = FinchAdapter.request(:get, url <> "/xrpc/test", [])
  end

  test "the pool name points at the supervised Finch instance" do
    assert FinchAdapter.pool_name() == ProtoRune.Finch
    assert pid = Process.whereis(ProtoRune.Finch)
    assert is_pid(pid) and Process.alive?(pid)
  end
end
