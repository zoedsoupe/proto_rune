defmodule ProtoRune.Atproto.SyncTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Sync

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  @car_fixture Path.expand("../../fixtures/sync/repo.car", __DIR__)

  setup do
    Application.put_env(:proto_rune, :http_client, HTTPStub)

    on_exit(fn ->
      Application.delete_env(:proto_rune, :http_client)
      Application.delete_env(:proto_rune, :http_stub_handler)
    end)

    :ok
  end

  defp stub(test_pid, response) do
    Application.put_env(:proto_rune, :http_stub_handler, fn method, url, opts ->
      send(test_pid, {:request, method, url, opts})
      {:ok, response}
    end)
  end

  describe "describe_repo/2" do
    test "queries the PDS with the repo parameter and decodes JSON" do
      body =
        JSON.encode!(%{
          "handle" => "alice.test",
          "did" => "did:plc:abc123",
          "didDoc" => %{"id" => "did:plc:abc123"},
          "collections" => ["com.example.post"],
          "handleIsCorrect" => true
        })

      stub(self(), %{status: 200, body: body, headers: [{"content-type", "application/json"}]})

      assert {:ok, %{did: "did:plc:abc123", handle_is_correct: true}} =
               Sync.describe_repo("https://pds.test", "alice.test")

      assert_received {:request, :get, url, opts}
      assert url == "https://pds.test/xrpc/com.atproto.sync.describeRepo?repo=alice.test"
      refute List.keyfind(Keyword.get(opts, :headers, []), "authorization", 0)
    end

    test "accepts an /xrpc-suffixed PDS URL" do
      stub(self(), %{status: 200, body: JSON.encode!(%{"did" => "did:plc:abc123"})})

      assert {:ok, %{did: "did:plc:abc123"}} =
               Sync.describe_repo("https://pds.test/xrpc", "did:plc:abc123")

      assert_received {:request, :get, url, _opts}
      assert String.starts_with?(url, "https://pds.test/xrpc/com.atproto.sync.describeRepo")
    end
  end

  describe "get_blob/3" do
    test "returns the raw body with its content type" do
      blob = :crypto.strong_rand_bytes(64)

      stub(self(), %{status: 200, body: blob, headers: [{"content-type", "image/png"}]})

      assert {:ok, %{content_type: "image/png", body: ^blob}} =
               Sync.get_blob("https://pds.test", "did:plc:abc123", "bafkreifake")

      assert_received {:request, :get, url, _opts}
      assert String.starts_with?(url, "https://pds.test/xrpc/com.atproto.sync.getBlob?")

      assert URI.decode_query(URI.parse(url).query) == %{
               "did" => "did:plc:abc123",
               "cid" => "bafkreifake"
             }
    end
  end

  describe "get_repo/2" do
    test "returns the CAR bytes as a binary body" do
      car = File.read!(@car_fixture)

      stub(self(), %{status: 200, body: car, headers: [{"content-type", "application/vnd.ipld.car"}]})

      assert {:ok, %{content_type: "application/vnd.ipld.car", body: ^car}} =
               Sync.get_repo("https://pds.test", "did:plc:abc123")

      assert_received {:request, :get, url, _opts}
      assert url == "https://pds.test/xrpc/com.atproto.sync.getRepo?did=did%3Aplc%3Aabc123"
    end
  end

  describe "parse_car/1" do
    test "decodes the fixture CAR into cid => block entries" do
      assert {:ok, blocks} = Sync.parse_car(File.read!(@car_fixture))

      # commit + 4 MST nodes + 5 records
      assert map_size(blocks) == 10

      assert Enum.all?(blocks, fn {%ProtoRune.CID{version: 1}, block} -> is_map(block) end)
    end

    test "accepts the {:ok, %{body: car}} tuple returned by get_repo/2" do
      car = File.read!(@car_fixture)

      assert {:ok, blocks} = Sync.parse_car({:ok, %{body: car}})
      assert map_size(blocks) == 10
    end

    test "returns an error on malformed data" do
      assert {:error, :invalid_varint} = Sync.parse_car(<<>>)
    end
  end
end
