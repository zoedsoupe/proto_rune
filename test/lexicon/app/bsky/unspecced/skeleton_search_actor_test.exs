defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchActorTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchActor

  describe "changeset/2" do
    test "validates required fields" do
      changeset = SkeletonSearchActor.changeset(%SkeletonSearchActor{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).did
    end

    test "validates DID format" do
      # Valid DID
      changeset =
        SkeletonSearchActor.changeset(%SkeletonSearchActor{}, %{
          did: "did:plc:1234abcd"
        })

      assert changeset.valid?

      # Invalid DID
      changeset =
        SkeletonSearchActor.changeset(%SkeletonSearchActor{}, %{
          did: "invalid-did"
        })

      refute changeset.valid?
      assert "must be a valid DID format" in errors_on(changeset).did
    end
  end

  describe "new/1" do
    test "creates a valid skeleton search actor" do
      did = "did:plc:1234abcd"
      assert {:ok, skeleton} = SkeletonSearchActor.new(%{did: did})
      assert skeleton.did == did
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = SkeletonSearchActor.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid skeleton search actor" do
      did = "did:plc:1234abcd"
      assert %SkeletonSearchActor{} = skeleton = SkeletonSearchActor.new!(%{did: did})
      assert skeleton.did == did
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid skeleton search actor/, fn ->
        SkeletonSearchActor.new!(%{})
      end
    end
  end
end
