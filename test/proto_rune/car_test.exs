defmodule ProtoRune.CARTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CAR
  alias ProtoRune.CBOR
  alias ProtoRune.CID

  @fixtures_dir Path.expand("../fixtures/firehose", __DIR__)

  defp commit_blocks(fixture) do
    data = File.read!(Path.join(@fixtures_dir, fixture))
    {:ok, _header, rest} = CBOR.decode(data)
    {:ok, payload, _rest} = CBOR.decode(rest)
    payload["blocks"]
  end

  describe "read/1 with real firehose data" do
    test "parses the blocks of a commit event" do
      assert {:ok, car} = CAR.read(commit_blocks("frame_00.bin"))

      assert [%CID{} | _] = car.roots
      assert [{%CID{}, block} | _] = car.blocks
      assert is_binary(block)

      assert Enum.all?(car.blocks, fn {cid, _block} ->
               cid.version == 1 and String.starts_with?(CID.to_string(cid), "b")
             end)
    end

    test "block data decodes as CBOR" do
      {:ok, car} = CAR.read(commit_blocks("frame_00.bin"))

      assert Enum.all?(car.blocks, fn {_cid, block} ->
               match?({:ok, value, <<>>} when is_map(value), CBOR.decode(block))
             end)
    end
  end

  describe "read/1 errors" do
    test "returns an error on empty input" do
      assert {:error, :invalid_varint} = CAR.read(<<>>)
    end

    test "returns an error on a non-CBOR header" do
      # segment of length 2 containing the integer 1 (not a map)
      assert {:error, :invalid_car_header} = CAR.read(<<0x02, 0x01, 0x20>>)
    end

    test "returns an error on a header without a version" do
      # segment of length 3 containing the map %{"a" => 1}
      assert {:error, :invalid_car_header} = CAR.read(<<0x04, 0xA1, 0x61, 0x61, 0x01>>)
    end

    test "returns an error on an unsupported version" do
      # segment containing the map %{"version" => 99, "roots" => []}
      header = <<0xA2, 0x67, "version", 0x18, 0x63, 0x65, "roots", 0x80>>
      assert {:error, {:unsupported_car_version, 99}} = CAR.read(<<byte_size(header), header::binary>>)
    end

    test "returns an error on truncated segments" do
      assert {:error, :unexpected_end} = CAR.read(<<0x05, 0x01, 0x02>>)
    end
  end
end
