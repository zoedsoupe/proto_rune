defmodule ProtoRune.BskyTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Bsky
  alias ProtoRune.XRPC.Error

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  @session %{access_jwt: "token123", did: "did:plc:test", service_url: "https://pds.test/xrpc"}

  setup do
    Application.put_env(:proto_rune, :http_client, HTTPStub)

    on_exit(fn ->
      Application.delete_env(:proto_rune, :http_client)
      Application.delete_env(:proto_rune, :http_stub_handler)
    end)

    :ok
  end

  defp stub(fun), do: Application.put_env(:proto_rune, :http_stub_handler, fun)

  defp ok(body), do: {:ok, %{status: 200, body: body}}

  describe "search_posts/3" do
    test "searches posts with a plain query" do
      stub(fn :get, url, opts ->
        send(self(), {:request, url, opts})

        ok(%{
          "posts" => [%{"uri" => "at://did:plc:x/app.bsky.feed.post/1", "cid" => "cid1"}],
          "cursor" => "next-page"
        })
      end)

      assert {:ok, %{posts: [%{uri: "at://did:plc:x/app.bsky.feed.post/1"}], cursor: "next-page"}} =
               Bsky.search_posts(@session, "elixir lang")

      assert_received {:request, url, opts}
      assert url =~ "app.bsky.feed.searchPosts"
      assert url =~ "q=elixir+lang"
      assert url =~ "limit=25"
      assert {"authorization", "Bearer token123"} in opts[:headers]
    end

    test "forwards search options" do
      stub(fn :get, url, _opts ->
        send(self(), {:request, url})
        ok(%{"posts" => []})
      end)

      assert {:ok, %{posts: []}} =
               Bsky.search_posts(@session, "elixir", sort: :latest, author: "alice.bsky.social", limit: 10)

      assert_received {:request, url}
      assert url =~ "sort=latest"
      assert url =~ "author=alice.bsky.social"
      assert url =~ "limit=10"
    end

    test "propagates request errors" do
      stub(fn :get, _url, _opts ->
        {:ok,
         %Req.Response{
           status: 400,
           body: %{"error" => "BadQueryString", "message" => "bad query"}
         }}
      end)

      assert {:error, %Error{reason: :bad_query_string}} = Bsky.search_posts(@session, "nope")
    end
  end

  describe "search_actors/3" do
    test "searches actors with a plain query" do
      stub(fn :get, url, _opts ->
        send(self(), {:request, url})

        ok(%{
          "actors" => [%{"did" => "did:plc:alice", "handle" => "alice.bsky.social"}],
          "cursor" => "next-page"
        })
      end)

      assert {:ok, %{actors: [%{handle: "alice.bsky.social"}], cursor: "next-page"}} =
               Bsky.search_actors(@session, "alice")

      assert_received {:request, url}
      assert url =~ "app.bsky.actor.searchActors"
      assert url =~ "q=alice"
      assert url =~ "limit=25"
    end

    test "forwards pagination options" do
      stub(fn :get, url, _opts ->
        send(self(), {:request, url})
        ok(%{"actors" => []})
      end)

      assert {:ok, %{actors: []}} = Bsky.search_actors(@session, "alice", limit: 5, cursor: "abc")

      assert_received {:request, url}
      assert url =~ "limit=5"
      assert url =~ "cursor=abc"
    end
  end

  describe "update_profile/2" do
    test "merges changes into the existing profile record" do
      stub(fn
        :get, url, _opts ->
          send(self(), {:request, :get, url})

          ok(%{
            "uri" => "at://did:plc:test/app.bsky.actor.profile/self",
            "cid" => "cid1",
            "value" => %{
              "$type" => "app.bsky.actor.profile",
              "displayName" => "Old Name",
              "description" => "old bio"
            }
          })

        :post, url, opts ->
          send(self(), {:request, :post, url, opts})
          ok(%{"uri" => "at://did:plc:test/app.bsky.actor.profile/self", "cid" => "cid2"})
      end)

      assert {:ok, %{cid: "cid2"}} = Bsky.update_profile(@session, display_name: "New Name")

      assert_received {:request, :get, get_url}
      assert get_url =~ "com.atproto.repo.getRecord"
      assert get_url =~ "collection=app.bsky.actor.profile"
      assert get_url =~ "rkey=self"

      assert_received {:request, :post, post_url, opts}
      assert post_url =~ "com.atproto.repo.putRecord"

      body = opts[:json]
      assert body[:repo] == "did:plc:test"
      assert body[:collection] == "app.bsky.actor.profile"
      assert body[:rkey] == "self"
      assert body[:record][:"$type"] == "app.bsky.actor.profile"
      assert body[:record][:displayName] == "New Name"
      assert body[:record][:description] == "old bio"
    end

    test "uploads the avatar blob before writing the record" do
      stub(fn
        :get, _url, _opts ->
          ok(%{
            "uri" => "at://did:plc:test/app.bsky.actor.profile/self",
            "cid" => "cid1",
            "value" => %{"$type" => "app.bsky.actor.profile", "displayName" => "Alice"}
          })

        :post, url, opts ->
          send(self(), {:request, :post, url, opts})

          if url =~ "uploadBlob" do
            ok(%{
              "blob" => %{
                "$type" => "blob",
                "ref" => %{"$link" => "bafkreid"},
                "mimeType" => "image/png",
                "size" => 3
              }
            })
          else
            ok(%{"uri" => "at://did:plc:test/app.bsky.actor.profile/self", "cid" => "cid2"})
          end
      end)

      assert {:ok, %{cid: "cid2"}} =
               Bsky.update_profile(@session, avatar: {<<1, 2, 3>>, "image/png"})

      assert_received {:request, :post, upload_url, upload_opts}
      assert upload_url =~ "com.atproto.repo.uploadBlob"
      assert upload_opts[:body] == <<1, 2, 3>>
      assert {"content-type", "image/png"} in upload_opts[:headers]
      assert {"authorization", "Bearer token123"} in upload_opts[:headers]

      assert_received {:request, :post, put_url, put_opts}
      assert put_url =~ "com.atproto.repo.putRecord"
      assert put_opts[:json][:record][:avatar][:ref][:"$link"] == "bafkreid"
      assert put_opts[:json][:record][:avatar][:mimeType] == "image/png"
    end

    test "starts from an empty record when no profile exists yet" do
      stub(fn
        :get, _url, _opts ->
          {:ok,
           %Req.Response{
             status: 400,
             body: %{"error" => "RecordNotFound", "message" => "could not find record"}
           }}

        :post, url, opts ->
          send(self(), {:request, :post, url, opts})
          ok(%{"uri" => "at://did:plc:test/app.bsky.actor.profile/self", "cid" => "cid1"})
      end)

      assert {:ok, %{cid: "cid1"}} = Bsky.update_profile(@session, description: "hello")

      assert_received {:request, :post, _url, opts}
      assert opts[:json][:record][:"$type"] == "app.bsky.actor.profile"
      assert opts[:json][:record][:description] == "hello"
      refute Map.has_key?(opts[:json][:record], :displayName)
    end

    test "propagates errors from fetching the current profile" do
      stub(fn :get, _url, _opts ->
        {:ok,
         %Req.Response{
           status: 401,
           body: %{"error" => "ExpiredToken", "message" => "token expired"}
         }}
      end)

      assert {:error, %Error{reason: :expired_token}} =
               Bsky.update_profile(@session, display_name: "New Name")
    end
  end
end
