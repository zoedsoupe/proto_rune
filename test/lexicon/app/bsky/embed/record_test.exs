defmodule Lexicon.App.Bsky.Embed.RecordTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.Record

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Record.changeset(%Record{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).record
    end

    test "validates record format" do
      # Valid strongRef
      changeset =
        Record.changeset(%Record{}, %{
          record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}
        })

      assert changeset.valid?

      # Invalid - record is completely wrong type
      changeset =
        Record.changeset(%Record{}, %{
          record: "not-a-map"
        })

      refute changeset.valid?
      # The exact error message might vary due to how Ecto handles typecasting
      assert errors_on(changeset).record != []

      # Test missing URI
      {:error, changeset} = Record.new(%{record: %{cid: "bafyabc123"}})
      assert "must have a URI" in errors_on(changeset).record

      # Test missing CID
      {:error, changeset} = Record.new(%{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc"}})
      assert "must have a CID" in errors_on(changeset).record

      # Test invalid URI format
      {:error, changeset} = Record.new(%{record: %{uri: "invalid", cid: "bafyabc123"}})
      assert "must have a valid AT-URI" in errors_on(changeset).record
    end
  end

  describe "new/1" do
    test "creates a valid record embed" do
      record_data = %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}

      assert {:ok, record} = Record.new(%{record: record_data})
      assert record.record == record_data
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Record.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid record embed" do
      record_data = %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}

      assert %Record{} = record = Record.new!(%{record: record_data})
      assert record.record == record_data
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid record embed/, fn ->
        Record.new!(%{})
      end
    end
  end
end
