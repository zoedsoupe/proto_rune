defmodule ProtoRune.BskyPostTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Bsky
  alias ProtoRune.RichText

  @session %ProtoRune.Atproto.Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  setup do
    test_pid = self()

    http =
      fake_http(fn method, url, opts ->
        send(test_pid, {:request, method, url, opts})

        {:ok,
         %{
           status: 200,
           headers: %{},
           body: %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "cid1"}
         }}
      end)

    {:ok, http: http}
  end

  describe "post/3 with plain text" do
    test "sends a wire body that conforms to the createRecord schema", %{http: http} do
      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} =
               Bsky.post(@session, "Hello Bluesky!", http: http)

      assert_received {:request, :post, url, opts}
      assert url =~ "com.atproto.repo.createRecord"

      body = opts[:json]
      assert body[:repo] == "did:plc:test"
      assert body[:collection] == "app.bsky.feed.post"

      record = body[:record]
      assert record[:"$type"] == "app.bsky.feed.post"
      assert record[:text] == "Hello Bluesky!"
      refute Map.has_key?(record, :langs)
      assert is_binary(record[:createdAt])
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(record[:createdAt])
    end
  end

  describe "post/3 with rich text" do
    test "sends facets with camelized byte offsets on the wire", %{http: http} do
      {:ok, rt} =
        RichText.new()
        |> RichText.text("Olá, ")
        |> RichText.link("this project", "https://example.com")
        |> RichText.build()

      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} = Bsky.post(@session, rt, http: http)

      assert_received {:request, :post, _url, opts}

      body = opts[:json]
      assert body[:collection] == "app.bsky.feed.post"

      record = body[:record]
      assert record[:"$type"] == "app.bsky.feed.post"
      assert record[:text] == "Olá, this project"
      refute Map.has_key?(record, :langs)
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
    test "sends a wire body that conforms to the createRecord schema", %{http: http} do
      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} =
               Bsky.like(@session, "at://did:plc:x/app.bsky.feed.post/1", "cid1", http: http)

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
    test "sends a wire body that conforms to the createRecord schema", %{http: http} do
      assert {:ok, %{uri: "at://did:plc:test/app.bsky.feed.post/abc"}} =
               Bsky.repost(@session, "at://did:plc:x/app.bsky.feed.post/1", "cid1", http: http)

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

  describe "post/3 with the :langs option" do
    test "sends the given language codes", %{http: http} do
      assert {:ok, _} = Bsky.post(@session, "alô mundo", langs: ["pt"], http: http)

      assert_received {:request, :post, _url, opts}
      assert opts[:json][:record][:langs] == ["pt"]
    end
  end
end
