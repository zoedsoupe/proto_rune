defmodule ProtoRune.HTTPClient.Adapters.FinchTest do
  @moduledoc """
  Feature-parity tests for the Finch adapter against a real HTTP server
  (`ProtoRune.StubServer`), exercising the `ProtoRune.Finch` pool end to end.
  """

  use ProtoRune.TestCase, async: true

  alias ProtoRune.HTTPClient
  alias ProtoRune.HTTPClient.Adapters.Finch, as: FinchAdapter
  alias ProtoRune.StubServer

  setup do
    {:ok, server} = StubServer.open()
    {:ok, server: server, url: server.url}
  end

  test "sends json: bodies with the application/json content type", %{server: server, url: url} do
    StubServer.expect_once(server, "POST", "/json", fn req ->
      assert ["application/json"] = req.headers["content-type"]
      assert JSON.decode!(req.body) == %{"hello" => "world"}
      {200, [{"content-type", "application/json"}], ~s|{"ok":true}|}
    end)

    assert {:ok, %{status: 200, body: ~s|{"ok":true}|}} =
             FinchAdapter.request(:post, url <> "/json", json: %{hello: "world"})
  end

  test "sends form: bodies urlencoded with the form content type", %{server: server, url: url} do
    form = %{"grant_type" => "authorization_code", "code" => "abc 123"}

    StubServer.expect_once(server, "POST", "/token", fn req ->
      assert ["application/x-www-form-urlencoded"] = req.headers["content-type"]
      assert req.body == URI.encode_query(form)
      {200, [], "ok"}
    end)

    assert {:ok, %{status: 200}} = FinchAdapter.request(:post, url <> "/token", form: form)
  end

  test "sends raw body: with the caller's content type", %{server: server, url: url} do
    StubServer.expect_once(server, "POST", "/blob", fn req ->
      assert ["image/png"] = req.headers["content-type"]
      assert req.body == <<1, 2, 3>>
      {200, [], "ok"}
    end)

    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:post, url <> "/blob",
               body: <<1, 2, 3>>,
               headers: [{"content-type", "image/png"}]
             )
  end

  test "passes headers: through and asks for identity encoding", %{server: server, url: url} do
    StubServer.expect_once(server, "GET", "/xrpc/test", fn req ->
      assert ["identity"] = req.headers["accept-encoding"]
      assert ["value"] = req.headers["x-custom"]
      {200, [], "ok"}
    end)

    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:get, url <> "/xrpc/test", headers: [{"x-custom", "value"}])
  end

  test "honors a caller-provided accept-encoding over identity", %{server: server, url: url} do
    StubServer.expect_once(server, "GET", "/xrpc/test", fn req ->
      assert ["gzip"] = req.headers["accept-encoding"]
      {200, [], "ok"}
    end)

    assert {:ok, %{status: 200}} =
             FinchAdapter.request(:get, url <> "/xrpc/test", headers: [{"accept-encoding", "gzip"}])
  end

  test "returns response headers as a list of tuples and raw bodies", %{server: server, url: url} do
    StubServer.expect_once(server, "GET", "/xrpc/test", fn _req ->
      {200, [{"content-type", "application/json"}], ~s|{"a":1}|}
    end)

    {:ok, %{status: 200, headers: headers, body: body}} =
      FinchAdapter.request(:get, url <> "/xrpc/test", [])

    assert is_list(headers)
    assert {"content-type", value} = List.keyfind(headers, "content-type", 0)
    assert String.starts_with?(value, "application/json")
    assert body == ~s|{"a":1}|

    assert HTTPClient.get_header(headers, "content-type") == value
  end

  test "returns a timeout error when the server never responds", %{server: server, url: url} do
    StubServer.hang(server, "GET", "/xrpc/test")

    assert {:error, %{reason: :timeout}} =
             FinchAdapter.request(:get, url <> "/xrpc/test", timeout: 200)
  end

  test "connection errors are {:error, reason} without raising", %{server: server, url: url} do
    StubServer.down(server)

    assert {:error, _reason} = FinchAdapter.request(:get, url <> "/xrpc/test", [])
  end

  test "the pool name points at the supervised Finch instance" do
    assert FinchAdapter.pool_name() == ProtoRune.Finch
    assert pid = Process.whereis(ProtoRune.Finch)
    assert is_pid(pid) and Process.alive?(pid)
  end
end
