defmodule Lexicon.App.Bsky.Graph.ListViewerStateTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.ListViewerState

  describe "changeset/2" do
    test "validates blocked format" do
      # No fields provided
      changeset = ListViewerState.changeset(%ListViewerState{}, %{})
      assert changeset.valid?

      # Valid blocked URI
      changeset =
        ListViewerState.changeset(%ListViewerState{}, %{
          blocked: "at://did:plc:abc123/app.bsky.graph.block/123"
        })

      assert changeset.valid?

      # Invalid blocked (not a URI)
      changeset =
        ListViewerState.changeset(%ListViewerState{}, %{
          blocked: "not-an-at-uri"
        })

      refute changeset.valid?
      assert "must be an AT-URI" in errors_on(changeset).blocked
    end

    test "accepts muted boolean value" do
      changeset = ListViewerState.changeset(%ListViewerState{}, %{muted: true})
      assert changeset.valid?
      assert get_change(changeset, :muted) == true

      changeset = ListViewerState.changeset(%ListViewerState{}, %{muted: false})
      assert changeset.valid?
      assert get_change(changeset, :muted) == false
    end
  end

  describe "new/1" do
    test "creates a valid viewer state with no fields" do
      assert {:ok, viewer_state} = ListViewerState.new(%{})
      assert viewer_state.muted == nil
      assert viewer_state.blocked == nil
    end

    test "creates a valid viewer state with muted" do
      assert {:ok, viewer_state} = ListViewerState.new(%{muted: true})
      assert viewer_state.muted == true
      assert viewer_state.blocked == nil
    end

    test "creates a valid viewer state with blocked" do
      blocked = "at://did:plc:abc123/app.bsky.graph.block/123"
      assert {:ok, viewer_state} = ListViewerState.new(%{blocked: blocked})
      assert viewer_state.muted == nil
      assert viewer_state.blocked == blocked
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = ListViewerState.new(%{blocked: "invalid"})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid viewer state" do
      blocked = "at://did:plc:abc123/app.bsky.graph.block/123"

      assert %ListViewerState{} =
               viewer_state =
               ListViewerState.new!(%{
                 muted: true,
                 blocked: blocked
               })

      assert viewer_state.muted == true
      assert viewer_state.blocked == blocked
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid list viewer state/, fn ->
        ListViewerState.new!(%{blocked: "invalid"})
      end
    end
  end
end
