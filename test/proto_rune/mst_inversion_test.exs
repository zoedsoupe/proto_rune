defmodule ProtoRune.MSTInversionTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CAR
  alias ProtoRune.CBOR
  alias ProtoRune.CID
  alias ProtoRune.MST
  alias ProtoRune.MST.Inversion

  @interop_fixture Path.expand("../fixtures/firehose/commit-proof-fixtures.json", __DIR__)
  @firehose_fixtures Path.expand("../fixtures/firehose", __DIR__)

  describe "official commit-proof fixtures" do
    test "reproduces before and after roots and reverses every official operation" do
      fixtures = @interop_fixture |> File.read!() |> JSON.decode!()

      for fixture <- fixtures do
        {:ok, leaf_value} = CID.from_string(fixture["leafValue"])
        {:ok, previous_root, blocks} = build_tree(fixture["keys"], leaf_value)

        assert CID.to_string(previous_root) == fixture["rootBeforeCommit"],
               fixture["comment"]

        {new_root, blocks} = apply_fixture_changes(blocks, previous_root, fixture, leaf_value)

        assert CID.to_string(new_root) == fixture["rootAfterCommit"], fixture["comment"]

        proof_cids = MapSet.new(fixture["blocksInProof"])
        generated_cids = MapSet.new(Enum.map(Map.keys(blocks), &CID.to_string/1))
        assert MapSet.subset?(proof_cids, generated_cids), fixture["comment"]
        assert fixture["rootAfterCommit"] in fixture["blocksInProof"], fixture["comment"]

        proof_blocks =
          fixture["blocksInProof"]
          |> Enum.map(fn cid_string ->
            {:ok, cid} = CID.from_string(cid_string)
            cid
          end)
          |> then(&Map.take(blocks, &1))

        ops =
          Enum.map(fixture["adds"], fn path ->
            %{action: :create, path: path, cid: leaf_value}
          end) ++
            Enum.map(fixture["dels"], fn path ->
              %{action: :delete, path: path, cid: nil, prev: leaf_value}
            end)

        assert :ok = MST.verify_inversion(proof_blocks, new_root, previous_root, ops)
      end
    end
  end

  describe "verify_inversion/4" do
    test "restores the prior CID for an update" do
      {:ok, old_value} = CID.from_string("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      new_value = cid("new record")
      path = "com.example.post/update"
      {:ok, previous_root, blocks} = build_tree([path], old_value)
      {:ok, new_root, blocks} = Inversion.put_record(blocks, previous_root, path, new_value)

      assert :ok =
               MST.verify_inversion(
                 blocks,
                 new_root,
                 previous_root,
                 [%{action: :update, path: path, cid: new_value, prev: old_value}]
               )
    end

    test "a wrong previous CID recomputes a different root" do
      old_value = cid("old record")
      new_value = cid("new record")
      wrong_previous = cid("wrong previous record")
      path = "com.example.post/update"
      {:ok, previous_root, blocks} = build_tree([path], old_value)
      {:ok, new_root, blocks} = Inversion.put_record(blocks, previous_root, path, new_value)

      assert {:error, {:root_mismatch, ^previous_root, computed_root}} =
               MST.verify_inversion(
                 blocks,
                 new_root,
                 previous_root,
                 [%{action: :update, path: path, cid: new_value, prev: wrong_previous}]
               )

      refute computed_root == previous_root
    end

    test "requires previous CIDs for updates and deletes" do
      previous_root = cid("unread root")

      for action <- [:update, :delete] do
        path = "com.example.post/missing-prev"

        assert {:error, {^path, :missing_prev}} =
                 MST.verify_inversion(
                   %{},
                   previous_root,
                   previous_root,
                   [%{action: action, path: path, cid: nil}]
                 )
      end
    end

    test "checks update and create CIDs against the new tree" do
      actual = cid("actual record")
      claimed = cid("claimed record")
      path = "com.example.post/current"
      {:ok, root, blocks} = build_tree([path], actual)

      assert {:error, {^path, {:cid_mismatch, ^claimed, ^actual}}} =
               MST.verify_inversion(
                 blocks,
                 root,
                 root,
                 [%{action: :update, path: path, cid: claimed, prev: actual}]
               )

      assert {:error, {^path, {:cid_mismatch, ^claimed, ^actual}}} =
               MST.verify_inversion(
                 blocks,
                 root,
                 root,
                 [%{action: :create, path: path, cid: claimed}]
               )
    end

    test "requires delete paths to be absent from the new tree" do
      value = cid("record")
      path = "com.example.post/current"
      {:ok, root, blocks} = build_tree([path], value)

      assert {:error, {^path, {:still_present, ^value}}} =
               MST.verify_inversion(
                 blocks,
                 root,
                 root,
                 [%{action: :delete, path: path, cid: nil, prev: value}]
               )
    end

    test "rejects a missing previous repository root" do
      root = cid("root")

      assert {:error, :missing_prev_data} = MST.verify_inversion(%{}, root, nil, [])
    end

    test "an omitted operation cannot explain a changed root" do
      value = cid("created record")
      path = "com.example.post/created"
      {:ok, previous_root, blocks} = Inversion.empty_tree()
      {:ok, new_root, _blocks} = Inversion.put_record(blocks, previous_root, path, value)

      assert {:error, {:root_mismatch, ^previous_root, ^new_root}} =
               MST.verify_inversion(blocks, new_root, previous_root, [])
    end

    test "empty operations succeed only when the roots are equal" do
      {:ok, root, blocks} = Inversion.empty_tree()

      assert :ok = MST.verify_inversion(blocks, root, root, [])

      assert {:error, {:root_mismatch, other, ^root}} =
               MST.verify_inversion(blocks, root, cid("other root"), [])

      assert other == cid("other root")
    end

    test "reverses the final create in an empty repository" do
      value = cid("created record")
      path = "com.example.post/created"
      {:ok, previous_root, blocks} = Inversion.empty_tree()
      {:ok, new_root, blocks} = Inversion.put_record(blocks, previous_root, path, value)

      assert :ok =
               MST.verify_inversion(
                 blocks,
                 new_root,
                 previous_root,
                 [%{action: :create, path: path, cid: value}]
               )
    end

    test "prunes an opaque previous root without loading its block" do
      previous_key = "com.example.post/0"
      created_key = "com.example.post/1"
      value = cid("record")
      assert key_height(previous_key) == 0
      assert key_height(created_key) == 2

      {:ok, previous_root, blocks} = build_tree([previous_key], value)
      {:ok, new_root, complete_blocks} = Inversion.put_record(blocks, previous_root, created_key, value)
      op = %{action: :create, path: created_key, cid: value}

      assert :ok = MST.verify_inversion(complete_blocks, new_root, previous_root, [op])

      partial_blocks = Map.delete(complete_blocks, previous_root)
      assert :ok = MST.verify_inversion(partial_blocks, new_root, previous_root, [op])
    end

    test "rejects duplicate operation paths" do
      value = cid("record")
      path = "com.example.post/duplicate"
      {:ok, previous_root, blocks} = Inversion.empty_tree()
      {:ok, new_root, blocks} = Inversion.put_record(blocks, previous_root, path, value)

      duplicate_ops = [
        %{action: :create, path: path, cid: value},
        %{action: :create, path: path, cid: value}
      ]

      assert {:error, {^path, :duplicate_operation}} =
               MST.verify_inversion(blocks, new_root, previous_root, duplicate_ops)
    end

    test "fails closed when a needed contextual node is missing" do
      fixture = @interop_fixture |> File.read!() |> JSON.decode!() |> hd()
      {:ok, leaf_value} = CID.from_string(fixture["leafValue"])
      {:ok, root, blocks} = build_tree(fixture["keys"], leaf_value)

      {path, value, proof} =
        fixture["keys"]
        |> Enum.map(fn key ->
          {:ok, %{cid: value, nodes: nodes}} = MST.prove(blocks, root, key)
          {key, value, nodes}
        end)
        |> Enum.find(fn {_key, _value, nodes} -> length(nodes) > 1 end)

      missing = List.last(proof)
      partial_blocks = Map.delete(blocks, missing)

      assert {:error, {^path, {:missing_block, ^missing}}} =
               MST.verify_inversion(
                 partial_blocks,
                 root,
                 root,
                 [%{action: :create, path: path, cid: value}]
               )
    end

    test "rejects noncanonical prefix compression" do
      path = "com.example.post/b"
      other = "com.example.post/a"
      value = cid("record")
      entries = [encoded_entry("com.example.post/a", value, 0), encoded_entry(path, value, 0)]
      {root, root_block} = hashed_node(%{"l" => nil, "e" => entries})
      blocks = %{root => root_block}

      assert {:error, {^other, :noncanonical_key_prefix}} =
               MST.verify_inversion(
                 blocks,
                 root,
                 root,
                 [%{action: :update, path: other, cid: value, prev: value}]
               )
    end

    test "rejects invalid key order" do
      first = "com.example.post/b"
      second = "com.example.post/a"
      value = cid("record")

      entries = [
        encoded_entry(first, value, 0),
        encoded_entry(second, value, common_prefix_length(first, second))
      ]

      {root, root_block} = hashed_node(%{"l" => nil, "e" => entries})
      blocks = %{root => root_block}

      assert {:error, {^first, :invalid_key_order}} =
               MST.verify_inversion(
                 blocks,
                 root,
                 root,
                 [%{action: :update, path: first, cid: value, prev: value}]
               )
    end

    test "rejects a child node whose key is at the wrong depth" do
      parent_key = "com.example.post/m"

      child_key =
        0
        |> Stream.iterate(&(&1 + 1))
        |> Stream.map(fn index -> "com.example.post/" <> Integer.to_string(index) end)
        |> Enum.find(fn candidate ->
          candidate < parent_key and key_height(candidate) != key_height(parent_key) - 1
        end)

      value = cid("record")
      {child, child_block} = hashed_node(%{"l" => nil, "e" => [encoded_entry(child_key, value, 0)]})

      parent_node = %{
        "l" => link(child),
        "e" => [encoded_entry(parent_key, value, 0)]
      }

      {root, root_block} = hashed_node(parent_node)

      assert {:error, {^child_key, :invalid_key_depth}} =
               MST.verify_inversion(
                 %{child => child_block, root => root_block},
                 root,
                 root,
                 [%{action: :update, path: child_key, cid: value, prev: value}]
               )
    end
  end

  describe "firehose commit frames" do
    test "reverses live commit fixture payloads against prevData" do
      @firehose_fixtures
      |> Path.join("frame*.bin")
      |> Path.wildcard()
      |> Enum.each(fn path ->
        {:ok, header, payload} = decode_frame(File.read!(path))

        if header == %{"op" => 1, "t" => "#commit"} do
          {:ok, car} = CAR.read(payload["blocks"])

          blocks =
            Map.new(car.blocks, fn {cid, bytes} ->
              {:ok, decoded, <<>>} = CBOR.decode(bytes)
              {cid, decoded}
            end)

          commit = Map.fetch!(blocks, hd(car.roots))
          {:ok, new_root} = CID.from_link(commit["data"])
          {:ok, previous_root} = CID.from_link(payload["prevData"])

          ops =
            Enum.map(payload["ops"], fn op ->
              {:ok, cid} = optional_link(op["cid"])
              {:ok, prev} = optional_link(op["prev"])

              %{
                action: String.to_existing_atom(op["action"]),
                path: op["path"],
                cid: cid,
                prev: prev
              }
            end)

          assert :ok = MST.verify_inversion(blocks, new_root, previous_root, ops),
                 Path.basename(path)
        end
      end)
    end
  end

  defp build_tree(keys, value) do
    {:ok, root, blocks} = Inversion.empty_tree()

    Enum.reduce(keys, {:ok, root, blocks}, fn key, {:ok, root, blocks} ->
      Inversion.put_record(blocks, root, key, value)
    end)
  end

  defp apply_fixture_changes(blocks, root, fixture, value) do
    {root, blocks} =
      Enum.reduce(fixture["adds"], {root, blocks}, fn key, {root, blocks} ->
        {:ok, next_root, next_blocks} = Inversion.put_record(blocks, root, key, value)
        {next_root, next_blocks}
      end)

    Enum.reduce(fixture["dels"], {root, blocks}, fn key, {root, blocks} ->
      {:ok, next_root, next_blocks} = Inversion.delete_record(blocks, root, key)
      {next_root, next_blocks}
    end)
  end

  defp decode_frame(bytes) do
    with {:ok, header, rest} <- CBOR.decode(bytes),
         {:ok, payload, <<>>} <- CBOR.decode(rest) do
      {:ok, header, payload}
    end
  end

  defp optional_link(nil), do: {:ok, nil}
  defp optional_link(link), do: CID.from_link(link)

  defp encoded_entry(key, value, prefix) do
    suffix = binary_part(key, prefix, byte_size(key) - prefix)

    %{
      "p" => prefix,
      "k" => CBOR.bytes(suffix),
      "v" => link(value),
      "t" => nil
    }
  end

  defp hashed_node(node) do
    bytes = CBOR.encode(node)
    cid = CID.from_dag_cbor(bytes)
    {:ok, decoded, <<>>} = CBOR.decode(bytes)
    {cid, decoded}
  end

  defp cid(seed), do: CID.from_dag_cbor(CBOR.encode(%{"text" => seed}))

  defp link(cid), do: {:tag, 42, <<0, CID.to_binary(cid)::binary>>}

  defp key_height(key) do
    hash = :crypto.hash(:sha256, key)
    zero_bits = hash |> :binary.bin_to_list() |> Enum.reduce_while(0, &count_zero_bits/2)
    div(zero_bits, 2)
  end

  defp count_zero_bits(0, acc), do: {:cont, acc + 8}
  defp count_zero_bits(byte, acc), do: {:halt, acc + leading_zero_bits(byte)}

  defp leading_zero_bits(byte) do
    byte
    |> Integer.to_string(2)
    |> String.length()
    |> then(&(8 - &1))
  end

  defp common_prefix_length(left, right), do: common_prefix_length(left, right, 0)

  defp common_prefix_length(<<byte, left::binary>>, <<byte, right::binary>>, count),
    do: common_prefix_length(left, right, count + 1)

  defp common_prefix_length(_left, _right, count), do: count
end
