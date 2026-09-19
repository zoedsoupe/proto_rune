defmodule ProtoRune.CBOREncodeTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CBOR
  alias ProtoRune.CID
  alias ProtoRune.Varint

  defp cid(seed) do
    digest = :crypto.hash(:sha256, seed)
    %CID{version: 1, codec: 0x71, multihash: Varint.encode(0x12) <> Varint.encode(32) <> digest}
  end

  defp link(cid), do: {:tag, 42, <<0>> <> CID.to_binary(cid)}

  test "encodes scalars" do
    assert CBOR.encode(nil) == <<0xF6>>
    assert CBOR.encode(true) == <<0xF5>>
    assert CBOR.encode(false) == <<0xF4>>
    assert CBOR.encode(0) == <<0x00>>
    assert CBOR.encode(23) == <<0x17>>
    assert CBOR.encode(24) == <<0x18, 24>>
    assert CBOR.encode(-1) == <<0x20>>
    assert CBOR.encode(-24) == <<0x37>>
  end

  test "encodes valid UTF-8 binaries as text strings, others as byte strings" do
    assert CBOR.encode("hello") == <<0x65>> <> "hello"
    assert CBOR.encode(<<0xFF, 0xFE>>) == <<0x42, 0xFF, 0xFE>>
  end

  test "encodes CID links as tag 42 with a byte string value" do
    cid = cid("block")
    assert CBOR.encode(link(cid)) == <<0xD8, 0x2A>> <> CBOR.encode(<<0>> <> CID.to_binary(cid))
  end

  test "encodes maps with canonical key ordering (length, then bytewise)" do
    assert CBOR.encode(%{"bb" => 1, "a" => 2, "aa" => 3}) ==
             <<0xA3>> <>
               CBOR.encode("a") <>
               CBOR.encode(2) <>
               CBOR.encode("aa") <>
               CBOR.encode(3) <>
               CBOR.encode("bb") <> CBOR.encode(1)
  end

  test "round-trips a commit-shaped map through decode/1" do
    mst_root = cid("mst root")

    unsigned = %{
      "did" => "did:plc:test",
      "version" => 3,
      "data" => link(mst_root),
      "rev" => "3jxs2aaa2ai",
      "prev" => nil
    }

    assert {:ok, decoded, <<>>} = CBOR.decode(CBOR.encode(unsigned))
    assert decoded == unsigned
  end

  test "round-trips an MST node through decode/1" do
    node = %{
      "l" => nil,
      "e" => [
        %{"p" => 0, "k" => "com.example.post/aaa", "v" => link(cid("record")), "t" => nil}
      ]
    }

    assert {:ok, decoded, <<>>} = CBOR.decode(CBOR.encode(node))
    assert decoded == node
  end
end
