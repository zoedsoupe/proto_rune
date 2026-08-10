defmodule ProtoRune.CBORTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CBOR

  @fixtures_dir Path.expand("../fixtures/firehose", __DIR__)

  describe "decode/1 integers" do
    test "decodes unsigned integers (RFC 8949 appendix A)" do
      assert {:ok, 0, <<>>} = CBOR.decode(<<0x00>>)
      assert {:ok, 1, <<>>} = CBOR.decode(<<0x01>>)
      assert {:ok, 10, <<>>} = CBOR.decode(<<0x0A>>)
      assert {:ok, 23, <<>>} = CBOR.decode(<<0x17>>)
      assert {:ok, 24, <<>>} = CBOR.decode(<<0x18, 0x18>>)
      assert {:ok, 100, <<>>} = CBOR.decode(<<0x18, 0x64>>)
      assert {:ok, 1_000, <<>>} = CBOR.decode(<<0x19, 0x03, 0xE8>>)
      assert {:ok, 1_000_000, <<>>} = CBOR.decode(<<0x1A, 0x00, 0x0F, 0x42, 0x40>>)

      assert {:ok, 1_000_000_000_000, <<>>} =
               CBOR.decode(<<0x1B, 0x00, 0x00, 0x00, 0xE8, 0xD4, 0xA5, 0x10, 0x00>>)

      assert {:ok, 18_446_744_073_709_551_615, <<>>} =
               CBOR.decode(<<0x1B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>)
    end

    test "decodes negative integers" do
      assert {:ok, -1, <<>>} = CBOR.decode(<<0x20>>)
      assert {:ok, -10, <<>>} = CBOR.decode(<<0x29>>)
      assert {:ok, -100, <<>>} = CBOR.decode(<<0x38, 0x63>>)
      assert {:ok, -1_000, <<>>} = CBOR.decode(<<0x39, 0x03, 0xE7>>)
    end
  end

  describe "decode/1 strings" do
    test "decodes byte strings" do
      assert {:ok, <<>>, <<>>} = CBOR.decode(<<0x40>>)
      assert {:ok, <<1, 2, 3, 4>>, <<>>} = CBOR.decode(<<0x44, 0x01, 0x02, 0x03, 0x04>>)
    end

    test "decodes text strings" do
      assert {:ok, "", <<>>} = CBOR.decode(<<0x60>>)
      assert {:ok, "a", <<>>} = CBOR.decode(<<0x61, 0x61>>)
      assert {:ok, "IETF", <<>>} = CBOR.decode(<<0x64, 0x49, 0x45, 0x54, 0x46>>)
    end
  end

  describe "decode/1 compound values" do
    test "decodes arrays" do
      assert {:ok, [], <<>>} = CBOR.decode(<<0x80>>)
      assert {:ok, [1, 2, 3], <<>>} = CBOR.decode(<<0x83, 0x01, 0x02, 0x03>>)

      assert {:ok, [1, [2, 3], [4, 5]], <<>>} =
               CBOR.decode(<<0x83, 0x01, 0x82, 0x02, 0x03, 0x82, 0x04, 0x05>>)
    end

    test "decodes maps" do
      assert {:ok, %{}, <<>>} = CBOR.decode(<<0xA0>>)

      assert {:ok, %{"a" => 1, "b" => [2, 3]}, <<>>} =
               CBOR.decode(<<0xA2, 0x61, 0x61, 0x01, 0x61, 0x62, 0x82, 0x02, 0x03>>)
    end

    test "decodes nested structures" do
      # {"a": {"b": [{"c": true}]}}
      data =
        <<0xA1, 0x61, 0x61, 0xA1, 0x61, 0x62, 0x81, 0xA1, 0x61, 0x63, 0xF5>>

      assert {:ok, %{"a" => %{"b" => [%{"c" => true}]}}, <<>>} = CBOR.decode(data)
    end
  end

  describe "decode/1 tags and simple values" do
    test "decodes semantic tags as {:tag, number, value}" do
      assert {:ok, {:tag, 42, <<0>>}, <<>>} = CBOR.decode(<<0xD8, 0x2A, 0x41, 0x00>>)

      assert {:ok, {:tag, 0, "2013-03-21T20:04:00Z"}, <<>>} =
               CBOR.decode(<<0xC0, 0x74, "2013-03-21T20:04:00Z">>)
    end

    test "decodes booleans and null" do
      assert {:ok, false, <<>>} = CBOR.decode(<<0xF4>>)
      assert {:ok, true, <<>>} = CBOR.decode(<<0xF5>>)
      assert {:ok, nil, <<>>} = CBOR.decode(<<0xF6>>)
    end

    test "decodes 32 and 64-bit floats" do
      assert {:ok, 100_000.0, <<>>} = CBOR.decode(<<0xFA, 0x47, 0xC3, 0x50, 0x00>>)

      assert {:ok, 1.0e300, <<>>} =
               CBOR.decode(<<0xFB, 0x7E, 0x37, 0xE4, 0x3C, 0x88, 0x00, 0x75, 0x9C>>)
    end

    test "rejects half floats and simple values" do
      assert {:error, :unsupported_simple_value} = CBOR.decode(<<0xF9, 0x3C, 0x00>>)
      assert {:error, :unsupported_simple_value} = CBOR.decode(<<0xF8, 0x20>>)
    end
  end

  describe "decode/1 framing" do
    test "returns the unconsumed rest of the input" do
      assert {:ok, 1, <<0x02, 0x03>>} = CBOR.decode(<<0x01, 0x02, 0x03>>)
    end

    test "decodes concatenated values in sequence" do
      data = <<0x61, 0x61, 0x61, 0x62>>
      assert {:ok, "a", rest} = CBOR.decode(data)
      assert {:ok, "b", <<>>} = CBOR.decode(rest)
    end
  end

  describe "decode/1 errors" do
    test "returns an error on empty input" do
      assert {:error, :unexpected_end} = CBOR.decode(<<>>)
    end

    test "returns an error on truncated input" do
      assert {:error, :unexpected_end} = CBOR.decode(<<0x18>>)
      assert {:error, :unexpected_end} = CBOR.decode(<<0x41>>)
      assert {:error, :unexpected_end} = CBOR.decode(<<0x19, 0x03>>)
    end

    test "rejects indefinite-length items" do
      assert {:error, :indefinite_length} = CBOR.decode(<<0x9F, 0x01, 0xFF>>)
      assert {:error, :indefinite_length} = CBOR.decode(<<0xBF, 0xFF>>)
    end
  end

  describe "decode/1 with real firehose frames" do
    for fixture <- Path.wildcard(Path.join(@fixtures_dir, "frame_*.bin")) do
      @tag fixture: fixture
      test "decodes the header of #{Path.basename(fixture)}" do
        data = File.read!(unquote(fixture))

        assert {:ok, header, rest} = CBOR.decode(data)
        assert is_map(header)
        assert byte_size(rest) > 0
        assert header["op"] in [1, -1]

        assert {:ok, payload, _rest} = CBOR.decode(rest)
        assert is_map(payload)
      end
    end
  end
end
