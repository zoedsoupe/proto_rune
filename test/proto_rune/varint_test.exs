defmodule ProtoRune.VarintTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Varint

  describe "read/1" do
    test "reads single-byte values" do
      assert {:ok, 0, <<>>} = Varint.read(<<0>>)
      assert {:ok, 1, <<>>} = Varint.read(<<1>>)
      assert {:ok, 127, <<>>} = Varint.read(<<127>>)
    end

    test "reads multi-byte values" do
      assert {:ok, 128, <<>>} = Varint.read(<<0x80, 0x01>>)
      assert {:ok, 300, <<>>} = Varint.read(<<0xAC, 0x02>>)
      assert {:ok, 16_384, <<>>} = Varint.read(<<0x80, 0x80, 0x01>>)
    end

    test "returns the unconsumed rest" do
      assert {:ok, 300, "rest"} = Varint.read(<<0xAC, 0x02, "rest">>)
    end

    test "returns an error on empty or unterminated input" do
      assert {:error, :invalid_varint} = Varint.read(<<>>)
      assert {:error, :invalid_varint} = Varint.read(<<0x80>>)
    end

    test "returns an error on overlong varints" do
      assert {:error, :invalid_varint} = Varint.read(<<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01>>)
    end
  end

  describe "encode/1" do
    test "encodes single-byte values" do
      assert Varint.encode(0) == <<0>>
      assert Varint.encode(127) == <<127>>
    end

    test "encodes multi-byte values" do
      assert Varint.encode(128) == <<0x80, 0x01>>
      assert Varint.encode(300) == <<0xAC, 0x02>>
    end

    test "roundtrips with read/1" do
      for value <- [0, 1, 127, 128, 300, 16_383, 16_384, 4_294_967_295, 18_446_744_073_709_551_615] do
        assert {:ok, ^value, <<>>} = value |> Varint.encode() |> Varint.read()
      end
    end
  end
end
