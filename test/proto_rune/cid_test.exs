defmodule ProtoRune.CIDTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CID

  # CIDv1 (dag-cbor, sha2-256) captured from a live firehose commit event
  @cid_binary Base.decode16!("01711220C0BABF4DE5A988E81F967F36B1831067496BEA3DCF630F74D4018967AAF99D80")
  @cid_string "bafyreigaxk7u3znjrdub7ft7g2yygedhjfv6upopmmhxjvabrft2v6m5qa"

  describe "from_binary/1" do
    test "parses a CIDv1 into its fields" do
      assert {:ok, cid, <<>>} = CID.from_binary(@cid_binary)
      assert cid.version == 1
      assert cid.codec == 0x71
      assert byte_size(cid.multihash) == 34
    end

    test "returns the unconsumed rest" do
      assert {:ok, _cid, "rest"} = CID.from_binary(@cid_binary <> "rest")
    end

    test "returns an error on unsupported versions" do
      assert {:error, {:unsupported_cid_version, 42}} = CID.from_binary(<<42, 1, 2, 3>>)
    end

    test "returns an error on truncated input" do
      assert {:error, :unexpected_end} = CID.from_binary(<<>>)
      assert {:error, :unexpected_end} = CID.from_binary(binary_part(@cid_binary, 0, 10))
    end
  end

  describe "from_dag_cbor/1" do
    test "constructs a deterministic DAG-CBOR sha2-256 CID" do
      cid = CID.from_dag_cbor("abc")

      assert CID.to_binary(cid) ==
               Base.decode16!("01711220BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD")

      assert CID.to_string(cid) == "bafyreif2pall7dybz7vecqka3zo24irdwabwdi4wc55jznaq75q7eaavvu"
    end
  end

  describe "valid_bytes?/2" do
    test "accepts matching bytes" do
      cid = CID.from_dag_cbor("abc")
      assert CID.valid_bytes?(cid, "abc")
    end

    test "rejects tampered bytes and non-sha2-256 multihashes" do
      cid = CID.from_dag_cbor("abc")
      refute CID.valid_bytes?(cid, "abd")
      refute CID.valid_bytes?(%{cid | multihash: <<0x13, 0x20, :binary.part(cid.multihash, 2, 32)::binary>>}, "abc")
      refute CID.valid_bytes?(%{cid | multihash: <<0x12, 0x1F, :binary.part(cid.multihash, 2, 32)::binary>>}, "abc")
    end
  end

  describe "from_link/1" do
    test "decodes a DAG-CBOR CID link" do
      assert {:ok, cid} = CID.from_link({:tag, 42, <<0, @cid_binary::binary>>})
      assert CID.to_string(cid) == @cid_string
    end

    test "accepts an already-parsed CID" do
      assert {:ok, cid, <<>>} = CID.from_binary(@cid_binary)
      assert {:ok, ^cid} = CID.from_link(cid)
    end

    test "returns an error on non-link values" do
      assert {:error, :invalid_cid_link} = CID.from_link({:tag, 99, <<0>>})
      assert {:error, :invalid_cid_link} = CID.from_link("not a link")
    end

    test "returns an error on links with trailing garbage" do
      assert {:error, :unexpected_end} = CID.from_link({:tag, 42, <<0>>})
    end
  end

  describe "from_string/1" do
    test "parses the base32 multibase string form" do
      assert {:ok, cid} = CID.from_string(@cid_string)
      assert CID.to_binary(cid) == @cid_binary
    end

    test "roundtrips with to_string/1" do
      assert {:ok, cid, <<>>} = CID.from_binary(@cid_binary)
      assert {:ok, ^cid} = CID.from_string(CID.to_string(cid))
    end

    test "returns an error on invalid strings" do
      assert {:error, :invalid_cid_string} = CID.from_string("zdup")
      assert {:error, :invalid_cid_string} = CID.from_string("b!!!")
    end
  end

  describe "to_string/1" do
    test "encodes to the base32 multibase string form" do
      assert {:ok, cid, <<>>} = CID.from_binary(@cid_binary)
      assert CID.to_string(cid) == @cid_string
    end

    test "implements the String.Chars protocol" do
      assert {:ok, cid} = CID.from_link({:tag, 42, <<0, @cid_binary::binary>>})
      assert "#{cid}" == @cid_string
    end
  end

  describe "to_binary/1" do
    test "roundtrips with from_binary/1" do
      assert {:ok, cid, <<>>} = CID.from_binary(@cid_binary)
      assert CID.to_binary(cid) == @cid_binary
    end
  end
end
