defmodule ProtoRune.Firehose.FrameTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CID
  alias ProtoRune.Firehose.Event
  alias ProtoRune.Firehose.Frame

  @fixtures_dir Path.expand("../../fixtures/firehose", __DIR__)

  defp fixture(name), do: @fixtures_dir |> Path.join(name) |> File.read!()

  describe "decode/1 commit events" do
    test "decodes a commit frame with a create op" do
      assert {:ok, %Event{} = event} = Frame.decode(fixture("frame_00.bin"))

      assert event.type == :commit
      assert event.seq == 32_625_482_169
      assert event.repo == "did:plc:4vdi2b4k2klzdke344ag2njy"
      assert event.time == "2026-08-10T19:20:49.113Z"
      assert is_binary(event.rev)

      assert [%{action: :create, path: "app.bsky.feed.post/" <> _rkey, cid: %CID{}}] = event.ops
    end

    test "resolves the record of a create op from the blocks" do
      assert {:ok, %Event{} = event} = Frame.decode(fixture("frame_00.bin"))

      for %{cid: cid} when not is_nil(cid) <- event.ops do
        assert is_map_key(event.blocks, to_string(cid))
      end

      [%{cid: cid} | _] = event.ops
      record = event.blocks[to_string(cid)]
      assert record["$type"] == "app.bsky.feed.post"
      assert is_binary(record["text"])
    end

    test "decodes CID links inside records as CID structs" do
      assert {:ok, %Event{} = event} = Frame.decode(fixture("frame_00.bin"))

      [%{cid: cid} | _] = event.ops
      record = event.blocks[to_string(cid)]

      assert %CID{} = get_in(record, ["embed", "media", "external", "thumb", "ref"])
    end

    test "decodes a commit frame with a delete op" do
      assert {:ok, %Event{} = event} = Frame.decode(fixture("frame_delete.bin"))

      assert event.type == :commit
      assert event.repo == "did:plc:sp5liks5o7ra6j663zhv5rgi"
      assert [%{action: :delete, path: "app.bsky.graph.follow/3lnm6stbtwi2i", cid: nil}] = event.ops
    end
  end

  describe "decode/1 other events" do
    test "decodes an identity frame" do
      assert {:ok, %Event{} = event} = Frame.decode(fixture("frame_identity.bin"))

      assert event.type == :identity
      assert event.seq == 32_625_561_603
      assert event.repo == "did:plc:hoyoz2vqz74upepwfqoxcooz"
      assert event.time == "2026-08-10T19:24:04.480Z"
      assert event.ops == []
      assert event.blocks == %{}
    end

    test "decodes an error frame" do
      # %{"op" => -1} followed by %{"error" => "FutureCursor", "message" => "cursor too new"}
      data =
        <<0xA1, 0x62, "op", 0x20, 0xA2, 0x65, "error", 0x6C, "FutureCursor", 0x67, "message", 0x6E, "cursor too new">>

      assert {:ok, %Event{type: :error, seq: nil} = event} = Frame.decode(data)
      assert event.payload["error"] == "FutureCursor"
      assert event.payload["message"] == "cursor too new"
    end

    test "decodes an info frame" do
      # %{"op" => 1, "t" => "#info"} followed by %{"name" => "OutdatedCursor"}
      data =
        <<0xA2, 0x62, "op", 0x01, 0x61, "t", 0x65, "#info", 0xA1, 0x64, "name", 0x6E, "OutdatedCursor">>

      assert {:ok, %Event{type: :info, seq: nil} = event} = Frame.decode(data)
      assert event.payload["name"] == "OutdatedCursor"
    end

    test "decodes frames with unknown message types as :unknown" do
      # %{"op" => 1, "t" => "#somethingnew"} followed by %{"seq" => 5}
      data =
        <<0xA2, 0x62, "op", 0x01, 0x61, "t", 0x6D, "#somethingnew", 0xA1, 0x63, "seq", 0x05>>

      assert {:ok, %Event{type: :unknown, seq: 5}} = Frame.decode(data)
    end
  end

  describe "decode/1 errors" do
    test "returns an error on non-CBOR input" do
      assert {:error, _reason} = Frame.decode("not cbor at all, way too long to decode")
    end

    test "returns an error on non-map headers" do
      # [1, 2, 3] followed by %{"op" => 1}
      data = <<0x83, 0x01, 0x02, 0x03, 0xA1, 0x62, "op", 0x01>>
      assert {:error, :invalid_frame} = Frame.decode(data)
    end

    test "returns an error on headers without an op" do
      # %{"t" => "#commit"} followed by %{}
      data = <<0xA1, 0x61, "t", 0x67, "#commit", 0xA0>>
      assert {:error, :invalid_frame_header} = Frame.decode(data)
    end
  end
end
