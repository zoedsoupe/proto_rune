defmodule Lexicon.App.Bsky.Labeler.LabelViewerStateTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Labeler.LabelViewerState

  describe "changeset/2" do
    test "accepts empty attributes" do
      changeset = LabelViewerState.changeset(%LabelViewerState{}, %{})
      assert changeset.valid?
    end

    test "validates like format" do
      # Valid AT-URI
      changeset =
        LabelViewerState.changeset(%LabelViewerState{}, %{
          like: "at://did:plc:1234/app.bsky.feed.like/abc"
        })

      assert changeset.valid?

      # Invalid format
      changeset =
        LabelViewerState.changeset(%LabelViewerState{}, %{
          like: "not-an-at-uri"
        })

      refute changeset.valid?
      assert "must be a valid AT-URI" in errors_on(changeset).like

      # Nil value is valid
      changeset =
        LabelViewerState.changeset(%LabelViewerState{}, %{
          like: nil
        })

      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a valid labeler viewer state with empty attributes" do
      assert {:ok, state} = LabelViewerState.new(%{})
      assert state.like == nil
    end

    test "creates a valid labeler viewer state with like" do
      like_uri = "at://did:plc:1234/app.bsky.feed.like/abc"

      assert {:ok, state} = LabelViewerState.new(%{like: like_uri})
      assert state.like == like_uri
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = LabelViewerState.new(%{like: "invalid"})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid labeler viewer state" do
      like_uri = "at://did:plc:1234/app.bsky.feed.like/abc"

      assert %LabelViewerState{} = state = LabelViewerState.new!(%{like: like_uri})
      assert state.like == like_uri
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid labeler viewer state/, fn ->
        LabelViewerState.new!(%{like: "invalid"})
      end
    end
  end
end
