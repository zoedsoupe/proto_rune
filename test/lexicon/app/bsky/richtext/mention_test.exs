defmodule Lexicon.App.Bsky.Richtext.MentionTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Richtext.Mention

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Mention.changeset(%Mention{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).did
    end

    test "validates DID format" do
      # Valid DID
      changeset = Mention.changeset(%Mention{}, %{did: "did:plc:1234abcd"})
      assert changeset.valid?

      # Invalid format
      changeset = Mention.changeset(%Mention{}, %{did: "invalid-did"})
      refute changeset.valid?
      assert "must be a valid DID format" in errors_on(changeset).did
    end
  end

  describe "new/1" do
    test "creates a valid mention" do
      did = "did:plc:1234abcd"
      assert {:ok, mention} = Mention.new(%{did: did})
      assert mention.did == did
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Mention.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid mention" do
      did = "did:plc:1234abcd"
      assert %Mention{} = mention = Mention.new!(%{did: did})
      assert mention.did == did
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid mention/, fn ->
        Mention.new!(%{})
      end
    end
  end
end
