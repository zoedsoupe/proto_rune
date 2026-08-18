defmodule ProtoRune.BskyPostTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Bsky
  alias ProtoRune.RichText

  defmodule CaptureAdapter do
    @moduledoc false
    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      send(Process.whereis(:bsky_post_test), {:request, method, url, opts})

      {:ok,
       %{
         status: 200,
         headers: %{},
         body: %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "cid1"}
       }}
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
    previous = Application.get_env(:proto_rune, :http_client)
    on_exit(fn -> restore_env(:http_client, previous) end)

    Application.put_env(:proto_rune, :http_client, CaptureAdapter)
    Application.put_env(:proto_rune, :rate_limit, false)
    on_exit(fn -> Application.delete_env(:proto_rune, :rate_limit) end)

    Process.register(self(), :bsky_post_test)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:proto_rune, key)
  defp restore_env(key, value), do: Application.put_env(:proto_rune, key, value)

  describe "post/3 with plain text" do
    test "sends a wire body that conforms to the createRecord schema" do
      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} =
               Bsky.post(@session, "Hello Bluesky!")

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.createRecord"

      body = opts[:json]
      assert body[:repo] == "did:plc:test"
      assert body[:collection] == "app.bsky.feed.post"

      record = body[:record]
      assert record[:"$type"] == "app.bsky.feed.post"
      assert record[:text] == "Hello Bluesky!"
      assert record[:langs] == ["en"]
      assert is_binary(record[:createdAt])
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(record[:createdAt])
    end
  end

  describe "post/3 with rich text" do
    test "sends facets with camelized byte offsets on the wire" do
      {:ok, rt} =
        RichText.new()
        |> RichText.text("Olá, ")
        |> RichText.link("this project", "https://example.com")
        |> RichText.build()

      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} = Bsky.post(@session, rt)

      assert_received {:request, :post, _url, opts}

      body = opts[:json]
      assert body[:collection] == "app.bsky.feed.post"

      record = body[:record]
      assert record[:"$type"] == "app.bsky.feed.post"
      assert record[:text] == "Olá, this project"
      assert record[:langs] == ["en"]
      assert is_binary(record[:createdAt])
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(record[:createdAt])

      # "Olá, " is 6 bytes (á is 2 bytes), so the link spans bytes 6..18
      assert [%{index: index, features: [feature]}] = record[:facets]
      assert index == %{byteStart: 6, byteEnd: 18}
      assert feature[:"$type"] == "app.bsky.richtext.facet#link"
      assert feature[:uri] == "https://example.com"
    end
  end

  describe "like/3" do
    test "sends a wire body that conforms to the createRecord schema" do
      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} =
               Bsky.like(@session, "at://did:plc:x/app.bsky.feed.post/1", "cid1")

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.createRecord"

      body = opts[:json]
      assert body[:repo] == "did:plc:test"
      assert body[:collection] == "app.bsky.feed.like"

      record = body[:record]
      assert record[:"$type"] == "app.bsky.feed.like"
      assert record[:subject] == %{uri: "at://did:plc:x/app.bsky.feed.post/1", cid: "cid1"}
      assert is_binary(record[:createdAt])
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(record[:createdAt])
    end
  end

  describe "repost/3" do
    test "sends a wire body that conforms to the createRecord schema" do
      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} =
               Bsky.repost(@session, "at://did:plc:x/app.bsky.feed.post/1", "cid1")

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.createRecord"

      body = opts[:json]
      assert body[:repo] == "did:plc:test"
      assert body[:collection] == "app.bsky.feed.repost"

      record = body[:record]
      assert record[:"$type"] == "app.bsky.feed.repost"
      assert record[:subject] == %{uri: "at://did:plc:x/app.bsky.feed.post/1", cid: "cid1"}
      assert is_binary(record[:createdAt])
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(record[:createdAt])
    end
  end

  describe "Repo.parse_record_schema/1" do
    test "returns schemas for supported collections" do
      assert {:ok, post_schema} = Repo.parse_record_schema(%{collection: :post})
      assert {:ok, like_schema} = Repo.parse_record_schema(%{collection: :like})
      assert {:ok, repost_schema} = Repo.parse_record_schema(%{collection: :repost})
      assert is_map(post_schema)
      assert is_map(like_schema)
      assert is_map(repost_schema)
    end

    test "returns an error tuple instead of crashing for unsupported collections" do
      assert {:error, {:unsupported_collection, :threadgate}} =
               Repo.parse_record_schema(%{collection: :threadgate})

      assert {:error, {:unsupported_collection, "app.bsky.feed.post"}} =
               Repo.parse_record_schema(%{collection: "app.bsky.feed.post"})
    end
  end
end
