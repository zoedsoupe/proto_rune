defmodule Lexicon.App.Bsky.Graph.BlockTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.Block

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Block.changeset(%Block{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subject
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates subject format" do
      # Valid DID
      changeset =
        Block.changeset(%Block{}, %{
          subject: "did:plc:1234abcd",
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid subject (not a DID)
      changeset =
        Block.changeset(%Block{}, %{
          subject: "not-a-did",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "subject must be a DID" in errors_on(changeset).subject
    end
  end

  describe "new/1" do
    test "creates a valid block" do
      subject = "did:plc:1234abcd"
      assert {:ok, block} = Block.new(%{subject: subject})
      assert block.subject == subject
      assert %DateTime{} = block.created_at
    end

    test "creates a block with custom created_at" do
      subject = "did:plc:1234abcd"
      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, block} =
               Block.new(%{
                 subject: subject,
                 created_at: created_at
               })

      assert block.subject == subject
      assert block.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Block.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid block" do
      subject = "did:plc:1234abcd"
      assert %Block{} = block = Block.new!(%{subject: subject})
      assert block.subject == subject
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid block/, fn ->
        Block.new!(%{})
      end
    end
  end
end
