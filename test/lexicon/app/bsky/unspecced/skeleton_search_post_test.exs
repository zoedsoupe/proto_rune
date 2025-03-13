defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchPostTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchPost

  describe "changeset/2" do
    test "validates required fields" do
      changeset = SkeletonSearchPost.changeset(%SkeletonSearchPost{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).uri
    end

    test "validates URI format" do
      # Valid AT-URI
      changeset =
        SkeletonSearchPost.changeset(%SkeletonSearchPost{}, %{
          uri: "at://did:plc:1234/app.bsky.feed.post/1"
        })

      assert changeset.valid?

      # Invalid URI
      changeset =
        SkeletonSearchPost.changeset(%SkeletonSearchPost{}, %{
          uri: "invalid-uri"
        })

      refute changeset.valid?
      assert "must be a valid AT-URI" in errors_on(changeset).uri
    end
  end

  describe "new/1" do
    test "creates a valid skeleton search post" do
      uri = "at://did:plc:1234/app.bsky.feed.post/1"
      assert {:ok, skeleton} = SkeletonSearchPost.new(%{uri: uri})
      assert skeleton.uri == uri
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = SkeletonSearchPost.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid skeleton search post" do
      uri = "at://did:plc:1234/app.bsky.feed.post/1"
      assert %SkeletonSearchPost{} = skeleton = SkeletonSearchPost.new!(%{uri: uri})
      assert skeleton.uri == uri
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid skeleton search post/, fn ->
        SkeletonSearchPost.new!(%{})
      end
    end
  end
end
