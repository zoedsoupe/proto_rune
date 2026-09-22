defmodule ProtoRune.Atproto.RepoTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Repo

  @session %ProtoRune.Atproto.Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  defp stub_json(test_pid, body) do
    fake_http(fn method, url, opts ->
      send(test_pid, {:request, method, url, opts})
      {:ok, %{status: 200, body: body}}
    end)
  end

  defp auth_header(opts) do
    case List.keyfind(Keyword.get(opts, :headers, []), "authorization", 0) do
      {"authorization", value} -> value
      nil -> nil
    end
  end

  describe "create_record" do
    test "custom string NSID passes through unvalidated and sends the NSID in the body" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/abc", "cid" => "bafy123"})

      record = %{"$type" => "com.example.thing", "anything" => "goes"}

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "com.example.thing",
                   record: record
                 }, http: http)

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.createRecord"
      assert auth_header(opts) == "Bearer token123"

      body = Keyword.fetch!(opts, :json)
      assert body[:collection] == "com.example.thing"
      assert body[:repo] == "did:plc:test"
      assert body[:record] == %{:"$type" => "com.example.thing", :anything => "goes"}
    end

    test "known bsky NSID validates against the built-in schema and passes through" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"})

      record = %{
        "$type": "app.bsky.feed.post",
        text: "hello",
        created_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "app.bsky.feed.post",
                   record: record
                 }, http: http)

      assert_received {:request, :post, _url, opts}
      assert Keyword.fetch!(opts, :json)[:collection] == "app.bsky.feed.post"
    end

    test "atom collection is rejected by the params schema and makes no request" do
      http = stub_json(self(), %{})

      assert {:error, _} =
               Repo.create_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: :post,
                   record: %{}
                 }, http: http)

      refute_received {:request, _, _, _}
    end

    test "string form of a known bsky NSID still gets the built-in validation" do
      http = stub_json(self(), %{})

      assert {:error, _} =
               Repo.create_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "app.bsky.feed.post",
                   record: %{"$type": "app.bsky.feed.post"}
                 }, http: http)

      refute_received {:request, _, _, _}
    end

    test "schema option validates a custom collection record" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/abc", "cid" => "bafy123"})

      schema = %{text: {:required, :string}}

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "com.example.thing", record: %{text: "hi"}},
                 schema: schema,
                 http: http
               )

      assert_received {:request, :post, _url, opts}
      assert Keyword.fetch!(opts, :json)[:collection] == "com.example.thing"
    end

    test "schema option returns the Peri error and makes no request on invalid records" do
      http = stub_json(self(), %{})

      schema = %{text: {:required, :string}}

      assert {:error, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "com.example.thing", record: %{}},
                 schema: schema,
                 http: http
               )

      refute_received {:request, _, _, _}
    end

    test "schema option overrides the built-in validation for known collections" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"})

      schema = %{text: {:required, :string}}

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "app.bsky.feed.post", record: %{text: "no dollar type needed"}},
                 schema: schema,
                 http: http
               )

      assert_received {:request, :post, _url, _opts}
    end

    test "optional params keep the same camelized wire keys" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"})

      record = %{"$type": "app.bsky.feed.post", text: "hello"}

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "app.bsky.feed.post",
                   rkey: "abc",
                   validate: false,
                   swap_commit: "bafyrei123",
                   record: record
                 }, http: http)

      assert_received {:request, :post, _url, opts}
      body = Keyword.fetch!(opts, :json)
      assert body[:rkey] == "abc"
      assert body[:validate] == false
      assert body[:swapCommit] == "bafyrei123"
    end
  end

  describe "put_record" do
    test "custom string NSID passes through unvalidated and sends the NSID in the body" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/self", "cid" => "bafy123"})

      record = %{"$type" => "com.example.thing", "anything" => "goes"}

      assert {:ok, _} =
               Repo.put_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "com.example.thing",
                   rkey: "self",
                   record: record
                 }, http: http)

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.putRecord"
      assert auth_header(opts) == "Bearer token123"

      body = Keyword.fetch!(opts, :json)
      assert body[:collection] == "com.example.thing"
      assert body[:rkey] == "self"
      assert body[:record] == %{:"$type" => "com.example.thing", :anything => "goes"}
    end

    test "atom collection is rejected by the params schema and makes no request" do
      http = stub_json(self(), %{})

      assert {:error, _} =
               Repo.put_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: :post,
                   rkey: "abc",
                   record: %{}
                 }, http: http)

      refute_received {:request, _, _, _}
    end

    test "string form of a known bsky NSID still gets the built-in validation" do
      http = stub_json(self(), %{})

      assert {:error, _} =
               Repo.put_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "app.bsky.feed.post",
                   rkey: "abc",
                   record: %{"$type": "app.bsky.feed.post"}
                 }, http: http)

      refute_received {:request, _, _, _}
    end

    test "schema option validates a custom collection record" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/self", "cid" => "bafy123"})

      schema = %{text: {:required, :string}}

      assert {:ok, _} =
               Repo.put_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "com.example.thing",
                   rkey: "self",
                   record: %{text: "hi"}
                 },
                 schema: schema,
                 http: http
               )

      assert_received {:request, :post, _url, _opts}
    end

    test "schema option returns the Peri error and makes no request on invalid records" do
      http = stub_json(self(), %{})

      schema = %{text: {:required, :string}}

      assert {:error, _} =
               Repo.put_record(
                 @session,
                 %{repo: "did:plc:test", collection: "com.example.thing", rkey: "self", record: %{}},
                 schema: schema,
                 http: http
               )

      refute_received {:request, _, _, _}
    end

    test "swap params keep the same camelized wire keys" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy456"})

      record = %{"$type": "app.bsky.feed.post", text: "updated"}

      assert {:ok, _} =
               Repo.put_record(
                 @session,
                 %{
                   repo: "did:plc:test",
                   collection: "app.bsky.feed.post",
                   rkey: "abc",
                   record: record,
                   swap_record: "bafy123",
                   swap_commit: "bafyrei123"
                 }, http: http)

      assert_received {:request, :post, _url, opts}
      body = Keyword.fetch!(opts, :json)
      assert body[:swapRecord] == "bafy123"
      assert body[:swapCommit] == "bafyrei123"
    end
  end

  describe "get_record" do
    test "with session sends the Bearer token" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc"})

      assert {:ok, _} =
               Repo.get_record(
                 @session,
                 %{repo: "did:plc:test", collection: "app.bsky.feed.post", rkey: "abc"},
                 http: http
               )

      assert_received {:request, :get, url, opts}
      assert url =~ "com.atproto.repo.getRecord"
      assert auth_header(opts) == "Bearer token123"
    end

    test "without session sends no authorization header" do
      http = stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc"})

      assert {:ok, _} =
               Repo.get_record(
                 nil,
                 %{repo: "did:plc:test", collection: "app.bsky.feed.post", rkey: "abc"},
                 http: http
               )

      assert_received {:request, :get, url, opts}
      assert url =~ "com.atproto.repo.getRecord"
      assert auth_header(opts) == nil
    end
  end

  describe "list_records" do
    test "with session sends the Bearer token" do
      http = stub_json(self(), %{"records" => []})

      assert {:ok, _} = Repo.list_records(@session, %{repo: "did:plc:test", collection: "app.bsky.feed.post"}, http: http)

      assert_received {:request, :get, _url, opts}
      assert auth_header(opts) == "Bearer token123"
    end

    test "without session sends no authorization header" do
      http = stub_json(self(), %{"records" => []})

      assert {:ok, _} = Repo.list_records(nil, %{repo: "did:plc:test", collection: "app.bsky.feed.post"}, http: http)

      assert_received {:request, :get, _url, opts}
      assert auth_header(opts) == nil
    end
  end
end
