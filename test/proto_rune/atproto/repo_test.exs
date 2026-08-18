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
