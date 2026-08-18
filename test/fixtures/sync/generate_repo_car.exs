# Generates test/fixtures/sync/repo.car, a small synthetic repository
# checkout (CAR v1) used by the sync and MST tests.
#
# Run from the project root:
#
#     mix run test/fixtures/sync/generate_repo_car.exs
#
# ProtoRune.CBOR only decodes, so this script carries the minimal DAG-CBOR
# encoder needed to build the fixture: integers, text strings, byte strings
# (wrapped as {:bytes, binary}), arrays, maps with canonical key ordering,
# nil and CID links (wrapped as {:link, %ProtoRune.CID{}}).

alias ProtoRune.CID
alias ProtoRune.Varint

defmodule DAGCBOR do
  @moduledoc false

  def encode(value) when is_integer(value) and value >= 0, do: head(0, value)
  def encode(value) when is_integer(value) and value < 0, do: head(1, -1 - value)
  def encode(nil), do: <<0xF6>>
  def encode(true), do: <<0xF5>>
  def encode(false), do: <<0xF4>>

  def encode({:bytes, bytes}) when is_binary(bytes), do: head(2, byte_size(bytes)) <> bytes

  def encode({:link, %CID{} = cid}) do
    {:bytes, <<0>> <> CID.to_binary(cid)} |> encode() |> then(&(<<0xD8, 0x2A>> <> &1))
  end

  def encode(value) when is_binary(value), do: head(3, byte_size(value)) <> value

  def encode(value) when is_list(value) do
    head(4, length(value)) <> Enum.map_join(value, &encode/1)
  end

  def encode(value) when is_map(value) do
    entries =
      value
      |> Enum.map(fn {key, val} -> {encode(key), encode(val)} end)
      |> Enum.sort_by(fn {key, _val} -> {byte_size(key), key} end)

    head(5, map_size(value)) <> Enum.map_join(entries, fn {key, val} -> key <> val end)
  end

  # major type head with the smallest argument encoding
  defp head(major, arg) when arg < 24, do: <<major::3, arg::5>>
  defp head(major, arg) when arg < 0x100, do: <<major::3, 24::5, arg::8>>
  defp head(major, arg) when arg < 0x10000, do: <<major::3, 25::5, arg::16>>
  defp head(major, arg) when arg < 0x100000000, do: <<major::3, 26::5, arg::32>>
  defp head(major, arg), do: <<major::3, 27::5, arg::64>>
end

defmodule RepoFixture do
  @moduledoc false

  @did "did:plc:fixturetest"

  def build do
    {records, record_blocks} = build_records()
    {mst_root, node_blocks} = build_mst(record_blocks)
    {commit_cid, commit_block} = build_commit(mst_root)

    blocks = [{commit_cid, commit_block} | node_blocks ++ Enum.map(records, & &1.block)]

    header = DAGCBOR.encode(%{"version" => 1, "roots" => [{:link, commit_cid}]})
    car = segment(header) <> Enum.map_join(blocks, fn {cid, bytes} -> segment(CID.to_binary(cid) <> bytes) end)

    {car, commit_cid}
  end

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
        bytes = DAGCBOR.encode(record)
        %{key: key, record: record, block: {cid_for(bytes), bytes}}
      end)

    record_blocks = Map.new(records, fn %{key: key, block: {cid, _bytes}} -> {key, cid} end)

    {records, record_blocks}
  end

  # Two-level tree exercising "l" and "t" links and prefix compression
  # across nodes:
  #
  #     [like/aaa1] < root{post/aaa2 -> [post/aab9], post/bbb3 -> [repost/ccc4]}
  defp build_mst(record_blocks) do
    {l1_cid, l1} =
      node(nil, [%{"p" => 0, "k" => "com.example.like/aaa1", "v" => record_blocks["com.example.like/aaa1"], "t" => nil}])

    {l2_cid, l2} =
      node(nil, [%{"p" => 19, "k" => "b9", "v" => record_blocks["com.example.post/aab9"], "t" => nil}])

    {l3_cid, l3} =
      node(nil, [%{"p" => 12, "k" => "repost/ccc4", "v" => record_blocks["com.example.repost/ccc4"], "t" => nil}])

    {root_cid, root} =
      node(l1_cid, [
        %{"p" => 12, "k" => "post/aaa2", "v" => record_blocks["com.example.post/aaa2"], "t" => l2_cid},
        %{"p" => 17, "k" => "bbb3", "v" => record_blocks["com.example.post/bbb3"], "t" => l3_cid}
      ])

    {root_cid, [{root_cid, root}, {l1_cid, l1}, {l2_cid, l2}, {l3_cid, l3}]}
  end

  defp node(left, entries) do
    encoded_entries =
      Enum.map(entries, fn entry ->
        %{
          "p" => entry["p"],
          "k" => {:bytes, entry["k"]},
          "v" => {:link, entry["v"]},
          "t" => link_or_nil(entry["t"])
        }
      end)

    bytes = DAGCBOR.encode(%{"l" => link_or_nil(left), "e" => encoded_entries})
    {cid_for(bytes), bytes}
  end

  defp link_or_nil(nil), do: nil
  defp link_or_nil(%CID{} = cid), do: {:link, cid}

  defp build_commit(mst_root) do
    commit = %{
      "did" => @did,
      "version" => 3,
      "data" => {:link, mst_root},
      "rev" => "3jxs2aaa2ai",
      "prev" => nil,
      "sig" => {:bytes, :crypto.strong_rand_bytes(64)}
    }

    bytes = DAGCBOR.encode(commit)
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
