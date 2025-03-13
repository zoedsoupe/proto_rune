defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchStarterPackTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchStarterPack

  describe "changeset/2" do
    test "validates required fields" do
      changeset = SkeletonSearchStarterPack.changeset(%SkeletonSearchStarterPack{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).uri
    end

    test "validates URI format" do
      # Valid AT-URI
      changeset =
        SkeletonSearchStarterPack.changeset(%SkeletonSearchStarterPack{}, %{
          uri: "at://did:plc:1234/app.bsky.graph.starterpack/1"
        })

      assert changeset.valid?

      # Invalid URI
      changeset =
        SkeletonSearchStarterPack.changeset(%SkeletonSearchStarterPack{}, %{
          uri: "invalid-uri"
        })

      refute changeset.valid?
      assert "must be a valid AT-URI" in errors_on(changeset).uri
    end
  end

  describe "new/1" do
    test "creates a valid skeleton search starter pack" do
      uri = "at://did:plc:1234/app.bsky.graph.starterpack/1"
      assert {:ok, skeleton} = SkeletonSearchStarterPack.new(%{uri: uri})
      assert skeleton.uri == uri
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = SkeletonSearchStarterPack.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid skeleton search starter pack" do
      uri = "at://did:plc:1234/app.bsky.graph.starterpack/1"
      assert %SkeletonSearchStarterPack{} = skeleton = SkeletonSearchStarterPack.new!(%{uri: uri})
      assert skeleton.uri == uri
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid skeleton search starter pack/, fn ->
        SkeletonSearchStarterPack.new!(%{})
      end
    end
  end
end
