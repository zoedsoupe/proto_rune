# Generates test/fixtures/sync/repo.car, a small synthetic repository
# checkout (CAR v1) used by the sync and MST tests.
#
# Run from the project root:
#
#     mix run test/fixtures/sync/generate_repo_car.ex

alias ProtoRune.CBOR
alias ProtoRune.CID
alias ProtoRune.Varint

defmodule RepoFixture do
  @moduledoc false

  @did "did:plc:fixturetest"

  def build do
    {records, record_blocks} = build_records()
    {mst_root, node_blocks} = build_mst(record_blocks)
    {commit_cid, commit_block} = build_commit(mst_root)

    blocks = [{commit_cid, commit_block} | node_blocks ++ Enum.map(records, & &1.block)]

    header = CBOR.encode(%{"version" => 1, "roots" => [link(commit_cid)]})
    car = segment(header) <> Enum.map_join(blocks, fn {cid, bytes} -> segment(CID.to_binary(cid) <> bytes) end)

    {car, commit_cid}
  end

  defp link(%CID{} = cid), do: {:tag, 42, <<0>> <> CID.to_binary(cid)}

  # Records keyed by their MST position (sorted traversal order)
  defp build_records do
    data = [
      {"com.example.like/aaa1",
       %{
         "$type" => "com.example.like",
         "subject" => "at://" <> @did <> "/com.example.post/aaa2",
         "createdAt" => "2026-01-02T00:00:00.000Z"
       }},
      {"com.example.post/aaa2",
       %{"$type" => "com.example.post", "text" => "first post", "createdAt" => "2026-01-01T00:00:00.000Z"}},
      {"com.example.post/aab9",
       %{"$type" => "com.example.post", "text" => "second post", "createdAt" => "2026-01-03T00:00:00.000Z"}},
      {"com.example.post/bbb3",
       %{"$type" => "com.example.post", "text" => "third post", "createdAt" => "2026-01-04T00:00:00.000Z"}},
      {"com.example.repost/ccc4",
       %{
         "$type" => "com.example.repost",
         "subject" => "at://" <> @did <> "/com.example.post/aab9",
         "createdAt" => "2026-01-05T00:00:00.000Z"
       }}
    ]

    records =
      Enum.map(data, fn {key, record} ->
        bytes = CBOR.encode(record)
        %{key: key, record: record, block: {cid_for(bytes), bytes}}
      end)

    record_blocks = Map.new(records, fn %{key: key, block: {cid, _bytes}} -> {key, cid} end)

    {records, record_blocks}
  end

  # Two-level tree exercising "l" and "t" links and prefix compression
  # within a node (the first entry of a node always stores its full key):
  #
  #     [like/aaa1] < root{post/aaa2 -> [post/aab9], post/bbb3 -> [repost/ccc4]}
  defp build_mst(record_blocks) do
    {l1_cid, l1} =
      node(nil, [%{"p" => 0, "k" => "com.example.like/aaa1", "v" => record_blocks["com.example.like/aaa1"], "t" => nil}])

    {l2_cid, l2} =
      node(nil, [%{"p" => 0, "k" => "com.example.post/aab9", "v" => record_blocks["com.example.post/aab9"], "t" => nil}])

    {l3_cid, l3} =
      node(nil, [
        %{"p" => 0, "k" => "com.example.repost/ccc4", "v" => record_blocks["com.example.repost/ccc4"], "t" => nil}
      ])

    {root_cid, root} =
      node(l1_cid, [
        %{"p" => 0, "k" => "com.example.post/aaa2", "v" => record_blocks["com.example.post/aaa2"], "t" => l2_cid},
        %{"p" => 17, "k" => "bbb3", "v" => record_blocks["com.example.post/bbb3"], "t" => l3_cid}
      ])

    {root_cid, [{root_cid, root}, {l1_cid, l1}, {l2_cid, l2}, {l3_cid, l3}]}
  end

  defp node(left, entries) do
    encoded_entries =
      Enum.map(entries, fn entry ->
        %{
          "p" => entry["p"],
          "k" => entry["k"],
          "v" => link(entry["v"]),
          "t" => link_or_nil(entry["t"])
        }
      end)

    bytes = CBOR.encode(%{"l" => link_or_nil(left), "e" => encoded_entries})
    {cid_for(bytes), bytes}
  end

  defp link_or_nil(nil), do: nil
  defp link_or_nil(%CID{} = cid), do: link(cid)

  defp build_commit(mst_root) do
    commit = %{
      "did" => @did,
      "version" => 3,
      "data" => link(mst_root),
      "rev" => "3jxs2aaa2ai",
      "prev" => nil,
      "sig" => :crypto.strong_rand_bytes(64)
    }

    bytes = CBOR.encode(commit)
    {cid_for(bytes), bytes}
  end

  defp cid_for(bytes) do
    digest = :crypto.hash(:sha256, bytes)
    %CID{version: 1, codec: 0x71, multihash: Varint.encode(0x12) <> Varint.encode(32) <> digest}
  end

  defp segment(data), do: Varint.encode(byte_size(data)) <> data
end

{car, commit_cid} = RepoFixture.build()
path = Path.expand("repo.car", __DIR__)
File.write!(path, car)
IO.puts("wrote #{byte_size(car)} bytes to #{path} (commit #{CID.to_string(commit_cid)})")
