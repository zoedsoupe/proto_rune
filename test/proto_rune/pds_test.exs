defmodule ProtoRune.PDSTest do
  @moduledoc """
  End-to-end tests against a fake PDS served by Bypass, exercising the
  real HTTP stack (Req adapter) instead of the env-stubbed adapter.
  """
  use ExUnit.Case, async: false

  import Plug.Conn

  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Atproto.Session
  alias ProtoRune.Atproto.Sync

  @did "did:plc:test"

  setup do
    bypass = Bypass.open()

    for key <- [:rate_limit, :retry] do
      previous = Application.get_env(:proto_rune, key)
      Application.put_env(:proto_rune, key, false)
      on_exit(fn -> restore_env(key, previous) end)
    end

    {:ok, bypass: bypass, url: "http://localhost:#{bypass.port}"}
  end

  defp restore_env(key, nil), do: Application.delete_env(:proto_rune, key)
  defp restore_env(key, value), do: Application.put_env(:proto_rune, key, value)

  defp session(url) do
    %Session{
      access_jwt: "token123",
      refresh_jwt: "refresh123",
      did: @did,
      handle: "alice.test",
      service_url: "#{url}/xrpc"
    }
  end

  defp json(conn, body) do
    conn
    |> put_resp_content_type("application/json")
    |> resp(200, JSON.encode!(body))
  end

  test "session login", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "POST", "/xrpc/com.atproto.server.createSession", fn conn ->
      {:ok, body, conn} = read_body(conn)
      assert %{"identifier" => "alice.test", "password" => "app-password"} = JSON.decode!(body)

      json(conn, %{
        "accessJwt" => "access",
        "refreshJwt" => "refresh",
        "handle" => "alice.test",
        "did" => @did
      })
    end)

    assert {:ok, %Session{access_jwt: "access", did: @did}} =
             ProtoRune.login("alice.test", "app-password", service: url)
  end

  test "record write sends the expected body and Bearer header", %{bypass: bypass, url: url} do
    Bypass.expect_once(bypass, "POST", "/xrpc/com.atproto.repo.createRecord", fn conn ->
      assert ["Bearer token123"] = get_req_header(conn, "authorization")

      {:ok, body, conn} = read_body(conn)

      assert %{
               "repo" => @did,
               "collection" => "app.bsky.feed.post",
               "record" => %{"$type" => "app.bsky.feed.post", "text" => "hello from bypass"}
             } = JSON.decode!(body)

      json(conn, %{"uri" => "at://#{@did}/app.bsky.feed.post/abc", "cid" => "bafy123"})
    end)

    assert {:ok, %{uri: "at://" <> _}} =
             Repo.create_record(session(url), %{
               repo: @did,
               collection: :post,
               record: %{"$type": "app.bsky.feed.post", text: "hello from bypass"}
             })
  end

  test "paginated listRecords follows cursors", %{bypass: bypass, url: url} do
    test_pid = self()

    Bypass.expect(bypass, "GET", "/xrpc/com.atproto.repo.listRecords", fn conn ->
      conn = fetch_query_params(conn)
      send(test_pid, {:list_records, conn.query_params["cursor"]})

      case conn.query_params["cursor"] do
        nil ->
          json(conn, %{"records" => [%{"uri" => "at://#{@did}/app.bsky.feed.post/1"}], "cursor" => "page2"})

        "page2" ->
          json(conn, %{"records" => [%{"uri" => "at://#{@did}/app.bsky.feed.post/2"}]})
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

  test "getBlob returns binary body with content type", %{bypass: bypass, url: url} do
    bytes = <<137, 80, 78, 71, 1, 2, 3>>

    Bypass.expect_once(bypass, "GET", "/xrpc/com.atproto.sync.getBlob", fn conn ->
      conn = fetch_query_params(conn)
      assert %{"did" => @did, "cid" => "bafyblob"} = conn.query_params

      conn
      |> put_resp_content_type("image/png")
      |> resp(200, bytes)
    end)

    assert {:ok, %{content_type: "image/png", body: ^bytes}} =
             Sync.get_blob(url, @did, "bafyblob")
  end

  test "getRepo returns a decodable CAR", %{bypass: bypass, url: url} do
    car = File.read!(Path.join([__DIR__, "..", "fixtures", "sync", "repo.car"]))

    Bypass.expect_once(bypass, "GET", "/xrpc/com.atproto.sync.getRepo", fn conn ->
      conn
      |> put_resp_content_type("application/vnd.ipld.car")
      |> resp(200, car)
    end)

    assert {:ok, %{body: body}} = Sync.get_repo(url, @did)
    assert {:ok, blocks} = Sync.parse_car(body)
    assert map_size(blocks) > 0
  end
end
