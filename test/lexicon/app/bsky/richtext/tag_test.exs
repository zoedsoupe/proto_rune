defmodule Lexicon.App.Bsky.Richtext.TagTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Richtext.Tag

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Tag.changeset(%Tag{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).tag
    end

    test "validates tag length" do
      # Valid tag
      changeset = Tag.changeset(%Tag{}, %{tag: "bluesky"})
      assert changeset.valid?

      # Too long (characters)
      too_long_tag = String.duplicate("x", 641)
      changeset = Tag.changeset(%Tag{}, %{tag: too_long_tag})
      refute changeset.valid?
      assert "should be at most 640 character(s)" in errors_on(changeset).tag

      # Too long (graphemes)
      too_many_graphemes = String.duplicate("🌟", 65)
      changeset = Tag.changeset(%Tag{}, %{tag: too_many_graphemes})
      refute changeset.valid?
      assert "should have at most 64 graphemes" in errors_on(changeset).tag
    end
  end

  describe "new/1" do
    test "creates a valid tag" do
      tag_text = "bluesky"
      assert {:ok, tag} = Tag.new(%{tag: tag_text})
      assert tag.tag == tag_text
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Tag.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid tag" do
      tag_text = "bluesky"
      assert %Tag{} = tag = Tag.new!(%{tag: tag_text})
      assert tag.tag == tag_text
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid tag/, fn ->
        Tag.new!(%{})
      end
    end
  end
end
