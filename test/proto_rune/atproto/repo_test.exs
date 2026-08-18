defmodule ProtoRune.Atproto.RepoTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Repo

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  @session %ProtoRune.Atproto.Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  setup do
    Application.put_env(:proto_rune, :http_client, HTTPStub)

    on_exit(fn ->
      Application.delete_env(:proto_rune, :http_client)
      Application.delete_env(:proto_rune, :http_stub_handler)
    end)

    :ok
  end

  defp stub_json(test_pid, body) do
    Application.put_env(:proto_rune, :http_stub_handler, fn method, url, opts ->
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
      stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/abc", "cid" => "bafy123"})

      record = %{"$type" => "com.example.thing", "anything" => "goes"}

      assert {:ok, _} =
               Repo.create_record(@session, %{
                 repo: "did:plc:test",
                 collection: "com.example.thing",
                 record: record
               })

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.createRecord"
      assert auth_header(opts) == "Bearer token123"

      body = Keyword.fetch!(opts, :json)
      assert body[:collection] == "com.example.thing"
      assert body[:repo] == "did:plc:test"
      assert body[:record] == %{:"$type" => "com.example.thing", :anything => "goes"}
    end

    test "atom collection encodes to the app.bsky.feed NSID and validates against the built-in schema" do
      stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"})

      record = %{
        "$type": "app.bsky.feed.post",
        text: "hello",
        created_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      assert {:ok, _} =
               Repo.create_record(@session, %{
                 repo: "did:plc:test",
                 collection: :post,
                 record: record
               })

      assert_received {:request, :post, _url, opts}
      assert Keyword.fetch!(opts, :json)[:collection] == "app.bsky.feed.post"
    end

    test "atom collection with an invalid record returns an error and makes no request" do
      stub_json(self(), %{})

      assert {:error, _} =
               Repo.create_record(@session, %{
                 repo: "did:plc:test",
                 collection: :post,
                 record: %{"$type": "app.bsky.feed.post"}
               })

      refute_received {:request, _, _, _}
    end

    test "unknown atom collection returns unsupported_collection and makes no request" do
      stub_json(self(), %{})

      assert {:error, {:unsupported_collection, :psot}} =
               Repo.create_record(@session, %{
                 repo: "did:plc:test",
                 collection: :psot,
                 record: %{}
               })

      refute_received {:request, _, _, _}
    end

    test "string form of a known bsky NSID still gets the built-in validation" do
      stub_json(self(), %{})

      assert {:error, _} =
               Repo.create_record(@session, %{
                 repo: "did:plc:test",
                 collection: "app.bsky.feed.post",
                 record: %{"$type": "app.bsky.feed.post"}
               })

      refute_received {:request, _, _, _}
    end

    test "schema option validates a custom collection record" do
      stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/abc", "cid" => "bafy123"})

      schema = %{text: {:required, :string}}

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "com.example.thing", record: %{text: "hi"}},
                 schema: schema
               )

      assert_received {:request, :post, _url, opts}
      assert Keyword.fetch!(opts, :json)[:collection] == "com.example.thing"
    end

    test "schema option returns the Peri error and makes no request on invalid records" do
      stub_json(self(), %{})

      schema = %{text: {:required, :string}}

      assert {:error, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "com.example.thing", record: %{}},
                 schema: schema
               )

      refute_received {:request, _, _, _}
    end

    test "schema option overrides the built-in validation for known collections" do
      stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"})

      schema = %{text: {:required, :string}}

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: :post, record: %{text: "no dollar type needed"}},
                 schema: schema
               )

      assert_received {:request, :post, _url, _opts}
    end

    test "optional params keep the same camelized wire keys" do
      stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"})

      record = %{"$type": "app.bsky.feed.post", text: "hello"}

      assert {:ok, _} =
               Repo.create_record(@session, %{
                 repo: "did:plc:test",
                 collection: :post,
                 rkey: "abc",
                 validate: false,
                 swap_commit: "bafyrei123",
                 record: record
               })

      assert_received {:request, :post, _url, opts}
      body = Keyword.fetch!(opts, :json)
      assert body[:rkey] == "abc"
      assert body[:validate] == false
      assert body[:swapCommit] == "bafyrei123"
    end
  end

  describe "put_record" do
    test "custom string NSID passes through unvalidated and sends the NSID in the body" do
      stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/self", "cid" => "bafy123"})

      record = %{"$type" => "com.example.thing", "anything" => "goes"}

      assert {:ok, _} =
               Repo.put_record(@session, %{
                 repo: "did:plc:test",
                 collection: "com.example.thing",
                 rkey: "self",
                 record: record
               })

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.putRecord"
      assert auth_header(opts) == "Bearer token123"

      body = Keyword.fetch!(opts, :json)
      assert body[:collection] == "com.example.thing"
      assert body[:rkey] == "self"
      assert body[:record] == %{:"$type" => "com.example.thing", :anything => "goes"}
    end

    test "atom collection with an invalid record returns an error and makes no request" do
      stub_json(self(), %{})

      assert {:error, _} =
               Repo.put_record(@session, %{
                 repo: "did:plc:test",
                 collection: :post,
                 rkey: "abc",
                 record: %{"$type": "app.bsky.feed.post"}
               })

      refute_received {:request, _, _, _}
    end

    test "unknown atom collection returns unsupported_collection and makes no request" do
      stub_json(self(), %{})

      assert {:error, {:unsupported_collection, :psot}} =
               Repo.put_record(@session, %{
                 repo: "did:plc:test",
                 collection: :psot,
                 rkey: "abc",
                 record: %{}
               })

      refute_received {:request, _, _, _}
    end

    test "string form of a known bsky NSID still gets the built-in validation" do
      stub_json(self(), %{})

      assert {:error, _} =
               Repo.put_record(@session, %{
                 repo: "did:plc:test",
                 collection: "app.bsky.feed.post",
                 rkey: "abc",
                 record: %{"$type": "app.bsky.feed.post"}
               })

      refute_received {:request, _, _, _}
    end

    test "schema option validates a custom collection record" do
      stub_json(self(), %{"uri" => "at://did:plc:test/com.example.thing/self", "cid" => "bafy123"})

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
                 schema: schema
               )

      assert_received {:request, :post, _url, _opts}
    end

    test "schema option returns the Peri error and makes no request on invalid records" do
      stub_json(self(), %{})

      schema = %{text: {:required, :string}}

      assert {:error, _} =
               Repo.put_record(
                 @session,
                 %{repo: "did:plc:test", collection: "com.example.thing", rkey: "self", record: %{}},
                 schema: schema
               )

      refute_received {:request, _, _, _}
    end

    test "swap params keep the same camelized wire keys" do
      stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy456"})

      record = %{"$type": "app.bsky.feed.post", text: "updated"}

      assert {:ok, _} =
               Repo.put_record(@session, %{
                 repo: "did:plc:test",
                 collection: :post,
                 rkey: "abc",
                 record: record,
                 swap_record: "bafy123",
                 swap_commit: "bafyrei123"
               })

      assert_received {:request, :post, _url, opts}
      body = Keyword.fetch!(opts, :json)
      assert body[:swapRecord] == "bafy123"
      assert body[:swapCommit] == "bafyrei123"
    end
  end

  describe "get_record" do
    test "with session sends the Bearer token" do
      stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc"})

      assert {:ok, _} =
               Repo.get_record(@session,
                 repo: "did:plc:test",
                 collection: "app.bsky.feed.post",
                 rkey: "abc"
               )

      assert_received {:request, :get, url, opts}
      assert url =~ "com.atproto.repo.getRecord"
      assert auth_header(opts) == "Bearer token123"
    end

    test "without session sends no authorization header" do
      stub_json(self(), %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc"})

      assert {:ok, _} =
               Repo.get_record(
                 repo: "did:plc:test",
                 collection: "app.bsky.feed.post",
                 rkey: "abc"
               )

      assert_received {:request, :get, url, opts}
      assert url =~ "com.atproto.repo.getRecord"
      assert auth_header(opts) == nil
    end
  end

  describe "list_records" do
    test "with session sends the Bearer token" do
      stub_json(self(), %{"records" => []})

      assert {:ok, _} = Repo.list_records(@session, repo: "did:plc:test", collection: "app.bsky.feed.post")

      assert_received {:request, :get, _url, opts}
      assert auth_header(opts) == "Bearer token123"
    end

    test "without session sends no authorization header" do
      stub_json(self(), %{"records" => []})

      assert {:ok, _} = Repo.list_records(repo: "did:plc:test", collection: "app.bsky.feed.post")

      assert_received {:request, :get, _url, opts}
      assert auth_header(opts) == nil
    end
  end
end
