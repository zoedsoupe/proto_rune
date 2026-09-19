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

  # Fabricates the same two-level tree as the CAR fixture, with
  # address-independent CIDs:
  #
  #     [like/aaa1] < root{post/aaa2 -> [post/aab9], post/bbb3 -> [repost/ccc4]}
  defp two_level_blocks do
    {record1, record2, record3, record4, record5} =
      {cid("r1"), cid("r2"), cid("r3"), cid("r4"), cid("r5")}

    {left, mid, right, root} = {cid("left"), cid("mid"), cid("right"), cid("root")}

    blocks = %{
      left => node(nil, [entry(0, "com.example.like/aaa1", record1)]),
      mid => node(nil, [entry(0, "com.example.post/aab9", record3)]),
      right => node(nil, [entry(0, "com.example.repost/ccc4", record5)]),
      root =>
        node(link(left), [
          entry(0, "com.example.post/aaa2", record2, link(mid)),
          entry(17, "bbb3", record4, link(right))
        ])
    }

    {blocks, root, [left, mid, right]}
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

    test "reconstructs each node's first key without context from other nodes" do
      # Prefix compression is local to each node: a first entry stores its
      # full key, no matter which keys its ancestors hold.
      {record1, record2} = {cid("record1"), cid("record2")}
      {left, root} = {cid("left"), cid("root")}

      blocks = %{
        left => node(nil, [entry(0, "com.example.like/aaa", record1)]),
        root => node(link(left), [entry(0, "zzz", record2)])
      }

      assert {:ok, [{"com.example.like/aaa", ^record1}, {"zzz", ^record2}]} =
               MST.entries(blocks, root)
    end

    test "walks left and entry subtrees depth-first in-order across levels" do
      {blocks, root, _children} = two_level_blocks()

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

  describe "prove/3" do
    test "collects the path to an entry at the root node" do
      {blocks, root, _children} = two_level_blocks()

      assert {:ok, %{key: "com.example.post/bbb3", cid: cid, nodes: [^root]}} =
               MST.prove(blocks, root, "com.example.post/bbb3")

      assert cid == cid("r4")
    end

    test "collects the path down to a subtree entry" do
      {blocks, root, [_left, mid, _right]} = two_level_blocks()

      assert {:ok, %{key: "com.example.post/aab9", cid: cid, nodes: [^root, ^mid]}} =
               MST.prove(blocks, root, "com.example.post/aab9")

      assert cid == cid("r3")
    end

    test "proves absence where the search reaches a null subtree" do
      {blocks, root, [_left, mid, _right]} = two_level_blocks()

      assert {:ok, %{key: "com.example.post/aab0", cid: nil, nodes: [^root, ^mid]}} =
               MST.prove(blocks, root, "com.example.post/aab0")
    end

    test "proves absence in an empty tree" do
      root = cid("empty")
      blocks = %{root => node(nil, [])}

      assert {:ok, %{key: "com.example.post/aaa", cid: nil, nodes: [^root]}} =
               MST.prove(blocks, root, "com.example.post/aaa")
    end

    test "returns an error when a node on the path is missing" do
      root = cid("root")
      blocks = %{root => node(link(cid("absent")), [])}

      assert {:error, {:missing_block, missing}} = MST.prove(blocks, root, "com.example.post/aaa")
      assert missing == cid("absent")
    end
  end

  describe "verify_proof/3" do
    test "verifies inclusion against the partial tree extracted by prove/3" do
      {blocks, mst_root} = fixture_blocks()
      {:ok, entries} = MST.entries(blocks, mst_root)

      for {key, cid} <- entries do
        assert {:ok, %{nodes: nodes}} = MST.prove(blocks, mst_root, key)
        slice = Map.take(blocks, nodes)
        assert {:ok, {:included, ^cid}} = MST.verify_proof(slice, mst_root, key)
      end
    end

    test "verifies absence against a partial tree" do
      {blocks, mst_root} = fixture_blocks()

      for key <- ["com.example.like/aaa0", "com.example.post/aab0", "com.example.zebra/zzzz"] do
        assert {:ok, %{cid: nil, nodes: nodes}} = MST.prove(blocks, mst_root, key)
        slice = Map.take(blocks, nodes)
        assert {:ok, :absent} = MST.verify_proof(slice, mst_root, key)
      end
    end

    test "reports a missing block when the slice cannot decide" do
      {blocks, root, [_left, mid, _right]} = two_level_blocks()
      slice = Map.take(blocks, [root])

      assert {:error, {:missing_block, ^mid}} = MST.verify_proof(slice, root, "com.example.post/aab9")
    end

    test "walks blocks whose CID links were already resolved" do
      {blocks, root, _children} = two_level_blocks()

      resolved =
        Map.new(blocks, fn {cid, node} ->
          {cid,
           %{
             "l" => resolve(node["l"]),
             "e" =>
               Enum.map(node["e"], fn entry ->
                 %{entry | "v" => resolve(entry["v"]), "t" => resolve(entry["t"])}
               end)
           }}
        end)

      assert {:ok, {:included, cid}} = MST.verify_proof(resolved, root, "com.example.post/aab9")
      assert cid == cid("r3")
    end
  end

  describe "verify_ops/3" do
    test "verifies create and update ops whose paths and CIDs match the tree" do
      {blocks, mst_root} = fixture_blocks()
      {:ok, entries} = MST.entries(blocks, mst_root)

      creates = Enum.map(entries, fn {path, cid} -> %{action: :create, path: path, cid: cid} end)
      updates = Enum.map(entries, fn {path, cid} -> %{action: :update, path: path, cid: cid} end)

      assert :ok = MST.verify_ops(blocks, mst_root, creates)
      assert :ok = MST.verify_ops(blocks, mst_root, updates)
    end

    test "verifies delete ops for paths the tree does not contain" do
      {blocks, mst_root} = fixture_blocks()

      ops = [
        %{action: :delete, path: "com.example.like/aaa0", cid: nil},
        %{action: :delete, path: "com.example.post/aab0", cid: nil}
      ]

      assert :ok = MST.verify_ops(blocks, mst_root, ops)
    end

    test "rejects a create op for a path the tree does not contain" do
      {blocks, mst_root} = fixture_blocks()
      ops = [%{action: :create, path: "com.example.post/nope", cid: cid("other")}]

      assert {:error, {"com.example.post/nope", :not_included}} = MST.verify_ops(blocks, mst_root, ops)
    end

    test "rejects an op whose claimed CID does not match the tree" do
      {blocks, mst_root} = fixture_blocks()
      claimed = cid("tampered")
      ops = [%{action: :update, path: "com.example.post/aab9", cid: claimed}]

      assert {:error, {"com.example.post/aab9", {:cid_mismatch, ^claimed, actual}}} =
               MST.verify_ops(blocks, mst_root, ops)

      assert actual != claimed
    end

    test "rejects a delete op for a path the tree still contains" do
      {blocks, mst_root} = fixture_blocks()
      ops = [%{action: :delete, path: "com.example.post/aab9", cid: nil}]

      assert {:error, {"com.example.post/aab9", {:still_present, _cid}}} =
               MST.verify_ops(blocks, mst_root, ops)
    end

    test "fails closed when the slice lacks a node needed to decide" do
      {blocks, mst_root} = fixture_blocks()
      root_node = Map.fetch!(blocks, mst_root)
      {:ok, mid} = root_node["e"] |> hd() |> Map.get("t") |> CID.from_link()

      ops = [%{action: :create, path: "com.example.post/aab9", cid: cid("r3")}]

      assert {:error, {"com.example.post/aab9", {:missing_block, ^mid}}} =
               MST.verify_ops(Map.take(blocks, [mst_root]), mst_root, ops)
    end
  end

  defp resolve(nil), do: nil
  defp resolve(link), do: elem(CID.from_link(link), 1)

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
