defmodule ProtoRune.PDSTest do
  @moduledoc """
  End-to-end tests against a fake PDS served by `ProtoRune.StubServer`,
  exercising the real HTTP stack (Finch adapter) instead of the
  env-stubbed adapter.
  """
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Atproto.Session
  alias ProtoRune.Atproto.Sync
  alias ProtoRune.StubServer

  @did "did:plc:test"

  setup do
    {:ok, server} = StubServer.open()
    {:ok, server: server, url: server.url}
  end

  defp session(url) do
    %Session{
      access_jwt: "token123",
      refresh_jwt: "refresh123",
      did: @did,
      handle: "alice.test",
      service_url: "#{url}/xrpc"
    }
  end

  defp json(body), do: {200, [{"content-type", "application/json"}], JSON.encode!(body)}

  test "session login", %{server: server, url: url} do
    StubServer.expect_once(server, "POST", "/xrpc/com.atproto.server.createSession", fn req ->
      assert %{"identifier" => "alice.test", "password" => "app-password"} = JSON.decode!(req.body)

      json(%{
        "accessJwt" => "access",
        "refreshJwt" => "refresh",
        "handle" => "alice.test",
        "did" => @did
      })
    end)

    assert {:ok, %Session{access_jwt: "access", did: @did}} =
             ProtoRune.login("alice.test", "app-password", service: url)
  end

  test "record write sends the expected body and Bearer header", %{server: server, url: url} do
    StubServer.expect_once(server, "POST", "/xrpc/com.atproto.repo.createRecord", fn req ->
      assert ["Bearer token123"] = req.headers["authorization"]

      assert %{
               "repo" => @did,
               "collection" => "app.bsky.feed.post",
               "record" => %{"$type" => "app.bsky.feed.post", "text" => "hello from the stub"}
             } = JSON.decode!(req.body)

      json(%{"uri" => "at://#{@did}/app.bsky.feed.post/abc", "cid" => "bafy123"})
    end)

    assert {:ok, %{uri: "at://" <> _}} =
             Repo.create_record(session(url), %{
               repo: @did,
               collection: "app.bsky.feed.post",
               record: %{"$type": "app.bsky.feed.post", text: "hello from the stub"}
             })
  end

  test "paginated listRecords follows cursors", %{server: server, url: url} do
    test_pid = self()

    StubServer.expect(server, "GET", "/xrpc/com.atproto.repo.listRecords", fn req ->
      send(test_pid, {:list_records, req.query["cursor"]})

      case req.query["cursor"] do
        nil ->
          json(%{"records" => [%{"uri" => "at://#{@did}/app.bsky.feed.post/1"}], "cursor" => "page2"})

        "page2" ->
          json(%{"records" => [%{"uri" => "at://#{@did}/app.bsky.feed.post/2"}]})
      end
    end)

    assert {:ok, %{records: [%{uri: "at://" <> _}], cursor: "page2"}} =
             Repo.list_records(session(url), repo: @did, collection: "app.bsky.feed.post")

    assert {:ok, %{records: [%{uri: second}]}} =
             Repo.list_records(session(url), repo: @did, collection: "app.bsky.feed.post", cursor: "page2")

    assert second =~ "app.bsky.feed.post/2"
    assert_received {:list_records, nil}
    assert_received {:list_records, "page2"}
  end

  test "getBlob returns binary body with content type", %{server: server, url: url} do
    bytes = <<137, 80, 78, 71, 1, 2, 3>>

    StubServer.expect_once(server, "GET", "/xrpc/com.atproto.sync.getBlob", fn req ->
      assert %{"did" => @did, "cid" => "bafyblob"} = req.query
      {200, [{"content-type", "image/png"}], bytes}
    end)

    assert {:ok, %{content_type: "image/png", body: ^bytes}} =
             Sync.get_blob(url, @did, "bafyblob")
  end

  test "getRepo returns a decodable CAR", %{server: server, url: url} do
    car = File.read!(Path.join([__DIR__, "..", "fixtures", "sync", "repo.car"]))

    StubServer.expect_once(server, "GET", "/xrpc/com.atproto.sync.getRepo", fn _req ->
      {200, [{"content-type", "application/vnd.ipld.car"}], car}
    end)

    assert {:ok, %{body: body}} = Sync.get_repo(url, @did)
    assert {:ok, blocks} = Sync.parse_car(body)
    assert map_size(blocks) > 0
  end
end
