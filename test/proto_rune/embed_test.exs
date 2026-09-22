defmodule ProtoRune.Bsky.EmbedTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Bsky
  alias ProtoRune.Bsky.Embed

  @session %ProtoRune.Atproto.Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  @blob %{"$type": "blob", ref: %{"$link": "bafkfake"}, mime_type: "image/png", size: 3}

  setup do
    test_pid = self()

    http =
      fake_http(fn method, url, opts ->
        send(test_pid, {:request, method, url, opts})

        body =
          if url =~ "uploadBlob" do
            %{"blob" => %{"$type" => "blob", "ref" => %{"$link" => "bafkfake"}, "mimeType" => "image/png", "size" => 3}}
          else
            %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "cid1"}
          end

        {:ok, %{status: 200, headers: %{}, body: body}}
      end)

    {:ok, http: http}
  end

  describe "builders" do
    test "images/1 builds an images embed with optional aspect ratio" do
      embed =
        Embed.images([
          %{alt: "a cat", image: @blob, aspect_ratio: %{width: 100, height: 80}},
          %{alt: "", image: @blob}
        ])

      assert embed[:"$type"] == "app.bsky.embed.images"

      assert [%{alt: "a cat", image: @blob, aspect_ratio: %{width: 100, height: 80}}, %{alt: "", image: @blob}] =
               embed[:images]
    end

    test "external/4 builds a link card with optional thumb" do
      assert Embed.external("https://x.test", "T", "D") ==
               %{:"$type" => "app.bsky.embed.external", external: %{uri: "https://x.test", title: "T", description: "D"}}

      with_thumb = Embed.external("https://x.test", "T", "D", @blob)
      assert with_thumb[:external][:thumb] == @blob
    end

    test "record/2 builds a quote embed" do
      assert Embed.record("at://did:plc:x/app.bsky.feed.post/1", "cid1") ==
               %{
                 :"$type" => "app.bsky.embed.record",
                 record: %{uri: "at://did:plc:x/app.bsky.feed.post/1", cid: "cid1"}
               }
    end

    test "record_with_media/2 nests a record and a media embed" do
      quote = Embed.record("at://did:plc:x/app.bsky.feed.post/1", "cid1")
      media = Embed.images([%{alt: "a cat", image: @blob}])

      assert Embed.record_with_media(quote, media) ==
               %{:"$type" => "app.bsky.embed.recordWithMedia", record: quote, media: media}
    end
  end

  describe "Bsky.post/3 with embeds" do
    test "attaches an embed map to the record", %{http: http} do
      embed = Embed.external("https://x.test", "Title", "Desc")

      assert {:ok, _} = Bsky.post(@session, "read this", embed: embed, http: http)

      assert_received {:request, :post, _url, opts}
      assert opts[:json][:record][:embed] == embed
    end

    test "uploads :images and attaches an images embed", %{http: http} do
      assert {:ok, _} = Bsky.post(@session, "cat tax", images: [{"png", "image/png", "a cat"}], http: http)

      assert_received {:request, :post, upload_url, upload_opts}
      assert upload_url =~ "com.atproto.repo.uploadBlob"
      assert upload_opts[:body] == "png"

      assert_received {:request, :post, _url, opts}
      embed = opts[:json][:record][:embed]
      assert embed[:"$type"] == "app.bsky.embed.images"
      # the captured body is the camelized wire form
      assert [%{alt: "a cat", image: %{mimeType: "image/png"}}] = embed[:images]
    end

    test "wraps a quote and :images into recordWithMedia", %{http: http} do
      quote = Embed.record("at://did:plc:x/app.bsky.feed.post/1", "cid1")

      assert {:ok, _} = Bsky.post(@session, "this!", embed: quote, images: [{"png", "image/png", "a cat"}], http: http)

      assert_received {:request, :post, upload_url, _opts}
      assert upload_url =~ "uploadBlob"

      assert_received {:request, :post, _url, opts}
      embed = opts[:json][:record][:embed]
      assert embed[:"$type"] == "app.bsky.embed.recordWithMedia"
      assert embed[:record] == quote
      assert embed[:media][:"$type"] == "app.bsky.embed.images"
    end

    test "refuses :images combined with a non-record embed", %{http: http} do
      card = Embed.external("https://x.test", "T", "D")

      assert {:error, :conflicting_embeds} =
               Bsky.post(@session, "nope", embed: card, images: [{"png", "image/png", "x"}], http: http)
    end
  end
end
