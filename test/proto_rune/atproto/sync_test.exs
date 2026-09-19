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

  describe "verify_checkout/2" do
    alias ProtoRune.CBOR
    alias ProtoRune.CID
    alias ProtoRune.MST
    alias ProtoRune.Varint

    @did "did:plc:checkouttest"

    defp cid_for(bytes) do
      digest = :crypto.hash(:sha256, bytes)
      %CID{version: 1, codec: 0x71, multihash: Varint.encode(0x12) <> Varint.encode(32) <> digest}
    end

    defp link(cid), do: {:tag, 42, <<0>> <> CID.to_binary(cid)}

    defp segment(data), do: Varint.encode(byte_size(data)) <> data

    defp base58_encode(binary) do
      zeros = byte_size(binary) - byte_size(String.trim_leading(binary, <<0>>))

      binary
      |> :binary.decode_unsigned()
      |> digits("")
      |> then(&(String.duplicate("1", zeros) <> &1))
    end

    @alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    defp digits(0, acc), do: acc

    defp digits(int, acc) do
      digits(div(int, 58), <<Enum.at(@alphabet, rem(int, 58))>> <> acc)
    end

    defp signing_material do
      {public, private} = :crypto.generate_key(:ecdh, :secp256r1)
      <<4, x::binary-32, y::binary-32>> = public
      prefix = if rem(:binary.last(y), 2) == 0, do: 0x02, else: 0x03
      multibase = "z" <> base58_encode(<<0x80, 0x24, prefix>> <> x)
      {private, multibase}
    end

    defp did_doc_body(multibase) do
      JSON.encode!(%{
        "id" => @did,
        "verificationMethod" => [
          %{"id" => @did <> "#atproto", "type" => "Multikey", "controller" => @did, "publicKeyMultibase" => multibase}
        ]
      })
    end

    # A checkout with a single record and a one-node MST, signed with a
    # fresh key. Returns {car_bytes, mst_root_cid, record_cid}.
    # With :corrupt_record, the record block's bytes no longer hash to its
    # CID (the commit itself stays valid).
    defp signed_checkout(private, opts \\ []) do
      record = %{"$type" => "com.example.post", "text" => "hello", "createdAt" => "2026-01-01T00:00:00.000Z"}
      record_bytes = CBOR.encode(record)
      record_cid = cid_for(record_bytes)

      record_bytes =
        if Keyword.get(opts, :corrupt_record, false) do
          size = byte_size(record_bytes) - 1
          <<head::binary-size(^size), last>> = record_bytes
          head <> <<Bitwise.bxor(last, 0xFF)>>
        else
          record_bytes
        end

      node = %{"l" => nil, "e" => [%{"p" => 0, "k" => "com.example.post/aaa", "v" => link(record_cid), "t" => nil}]}
      node_bytes = CBOR.encode(node)
      node_cid = cid_for(node_bytes)

      unsigned = %{
        "did" => Keyword.get(opts, :did, @did),
        "version" => 3,
        "data" => link(node_cid),
        "rev" => "3jxs2aaa2ai",
        "prev" => nil
      }

      der = :crypto.sign(:ecdsa, :sha256, CBOR.encode(unsigned), [private, :secp256r1])
      {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:"ECDSA-Sig-Value", der)
      commit_bytes = CBOR.encode(Map.put(unsigned, "sig", <<r::unsigned-big-256, s::unsigned-big-256>>))
      commit_cid = cid_for(commit_bytes)

      blocks = [{commit_cid, commit_bytes}, {node_cid, node_bytes}, {record_cid, record_bytes}]
      header = CBOR.encode(%{"version" => 1, "roots" => [link(commit_cid)]})
      car = segment(header) <> Enum.map_join(blocks, fn {cid, bytes} -> segment(CID.to_binary(cid) <> bytes) end)

      {car, node_cid, record_cid}
    end

    test "verifies a signed checkout and returns its blocks and MST root" do
      {private, multibase} = signing_material()
      {car, mst_root, _record_cid} = signed_checkout(private)

      stub(self(), %{status: 200, body: did_doc_body(multibase)})

      assert {:ok, %{did: @did, rev: "3jxs2aaa2ai", data: ^mst_root, blocks: blocks}} =
               Sync.verify_checkout(car)

      assert {:ok, %{"com.example.post/aaa" => %{"text" => "hello"}}} = MST.records(blocks, mst_root)

      assert_received {:request, :get, url, _opts}
      assert url == "https://plc.directory/#{@did}"
    end

    test "accepts the tuple returned by get_repo/2" do
      {private, multibase} = signing_material()
      {car, _mst_root, _record_cid} = signed_checkout(private)

      stub(self(), %{status: 200, body: did_doc_body(multibase)})

      assert {:ok, %{did: @did}} = Sync.verify_checkout({:ok, %{body: car}})
    end

    test "rejects a checkout whose commit did does not match the :did option" do
      {private, multibase} = signing_material()
      {car, _mst_root, _record_cid} = signed_checkout(private)

      stub(self(), %{status: 200, body: did_doc_body(multibase)})

      assert {:error, :did_mismatch} = Sync.verify_checkout(car, did: "did:plc:someoneelse")
      refute_received {:request, :get, _url, _opts}
    end

    test "rejects a tampered block" do
      {private, multibase} = signing_material()
      {car, _mst_root, record_cid} = signed_checkout(private, corrupt_record: true)

      stub(self(), %{status: 200, body: did_doc_body(multibase)})

      assert {:error, {:block_hash_mismatch, ^record_cid}} = Sync.verify_checkout(car)
      refute_received {:request, :get, _url, _opts}
    end

    test "rejects a commit signed with a different key than the DID document advertises" do
      {private, _multibase} = signing_material()
      {_other_private, other_multibase} = signing_material()
      {car, _mst_root, _record_cid} = signed_checkout(private)

      stub(self(), %{status: 200, body: did_doc_body(other_multibase)})

      assert {:error, :invalid_signature} = Sync.verify_checkout(car)
    end
  end
end
