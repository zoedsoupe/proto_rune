defmodule ProtoRune.MSTTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Atproto.Sync
  alias ProtoRune.CAR
  alias ProtoRune.CID
  alias ProtoRune.MST
  alias ProtoRune.Varint

  @fixture Path.expand("../fixtures/sync/repo.car", __DIR__)

  # Fabricates a CIDv1 (dag-cbor codec, sha2-256 multihash) for test blocks
  defp cid(seed) do
    digest = :crypto.hash(:sha256, seed)
    %CID{version: 1, codec: 0x71, multihash: Varint.encode(0x12) <> Varint.encode(32) <> digest}
  end

  defp link(cid), do: {:tag, 42, <<0>> <> CID.to_binary(cid)}

  defp node(left, entries) do
    %{"l" => left, "e" => entries}
  end

  defp entry(prefix_len, suffix, value_cid, tree_cid \\ nil) do
    %{"p" => prefix_len, "k" => suffix, "v" => link(value_cid), "t" => tree_cid}
  end

  defp fixture_blocks do
    bytes = File.read!(@fixture)
    {:ok, car} = CAR.read(bytes)
    {:ok, blocks} = Sync.parse_car(bytes)
    commit = Map.fetch!(blocks, hd(car.roots))
    {:ok, mst_root} = CID.from_link(commit["data"])
    {blocks, mst_root}
  end

  describe "entries/2" do
    test "returns an empty list for an empty tree" do
      root = cid("empty")
      blocks = %{root => node(nil, [])}

      assert {:ok, []} = MST.entries(blocks, root)
    end

    test "reconstructs keys within a single node" do
      {record1, record2} = {cid("record1"), cid("record2")}
      root = cid("root")

      blocks = %{
        root =>
          node(nil, [
            entry(0, "com.example.post/aaa", record1),
            entry(17, "bbb", record2)
          ])
      }

      assert {:ok, [{"com.example.post/aaa", ^record1}, {"com.example.post/bbb", ^record2}]} =
               MST.entries(blocks, root)
    end

    test "walks left and entry subtrees depth-first in-order across levels" do
      {record1, record2, record3, record4} = {cid("r1"), cid("r2"), cid("r3"), cid("r4")}
      {left, mid, right, root} = {cid("left"), cid("mid"), cid("right"), cid("root")}

      blocks = %{
        left => node(nil, [entry(0, "com.example.like/aaa1", record1)]),
        mid => node(nil, [entry(19, "b9", record3)]),
        right => node(nil, [entry(12, "repost/ccc4", record4)]),
        root =>
          node(link(left), [
            entry(12, "post/aaa2", record2, link(mid)),
            entry(17, "bbb3", record3, link(right))
          ])
      }

      assert {:ok, keys} = MST.entries(blocks, root)

      assert Enum.map(keys, &elem(&1, 0)) == [
               "com.example.like/aaa1",
               "com.example.post/aaa2",
               "com.example.post/aab9",
               "com.example.post/bbb3",
               "com.example.repost/ccc4"
             ]
    end

    test "returns entries in sorted key order" do
      {blocks, mst_root} = fixture_blocks()
      assert {:ok, entries} = MST.entries(blocks, mst_root)

      keys = Enum.map(entries, &elem(&1, 0))
      assert keys == Enum.sort(keys)
    end

    test "returns an error when a node block is missing" do
      root = cid("root")
      blocks = %{root => node(link(cid("absent")), [])}

      assert {:error, {:missing_block, missing}} = MST.entries(blocks, root)
      assert missing == cid("absent")
    end

    test "returns an error when an entry prefix exceeds the previous key" do
      root = cid("root")
      blocks = %{root => node(nil, [entry(10, "abc", cid("record"))])}

      assert {:error, :invalid_key_prefix} = MST.entries(blocks, root)
    end
  end

  describe "records/2" do
    test "resolves entry CIDs to their decoded blocks" do
      {record1, record2} = {%{"$type" => "com.example.post", "text" => "one"}, %{"text" => "two"}}
      {record1_cid, record2_cid} = {cid("record1"), cid("record2")}
      root = cid("root")

      blocks = %{
        root => node(nil, [entry(0, "com.example.post/aaa", record1_cid), entry(17, "bbb", record2_cid)]),
        record1_cid => record1,
        record2_cid => record2
      }

      assert {:ok, records} = MST.records(blocks, root)

      assert records == %{
               "com.example.post/aaa" => record1,
               "com.example.post/bbb" => record2
             }
    end

    test "returns an error when a record block is missing" do
      record_cid = cid("absent-record")
      root = cid("root")
      blocks = %{root => node(nil, [entry(0, "com.example.post/aaa", record_cid)])}

      assert {:error, {:missing_block, ^record_cid}} = MST.records(blocks, root)
    end
  end

  describe "fixture checkout" do
    test "enumerates every record of the generated repo CAR" do
      {blocks, mst_root} = fixture_blocks()

      assert {:ok, records} = MST.records(blocks, mst_root)

      assert records |> Map.keys() |> Enum.sort() == [
               "com.example.like/aaa1",
               "com.example.post/aaa2",
               "com.example.post/aab9",
               "com.example.post/bbb3",
               "com.example.repost/ccc4"
             ]

      assert records["com.example.post/aab9"]["text"] == "second post"
      assert records["com.example.like/aaa1"]["$type"] == "com.example.like"
    end
  end
end
