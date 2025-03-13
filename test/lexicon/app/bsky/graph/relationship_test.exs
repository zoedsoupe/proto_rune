defmodule Lexicon.App.Bsky.Graph.RelationshipTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.Relationship

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Relationship.changeset(%Relationship{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).did
    end

    test "validates DID format" do
      # Valid DID
      changeset =
        Relationship.changeset(%Relationship{}, %{
          did: "did:plc:1234abcd"
        })

      assert changeset.valid?

      # Invalid DID
      changeset =
        Relationship.changeset(%Relationship{}, %{
          did: "not-a-did"
        })

      refute changeset.valid?
      assert "must be a DID" in errors_on(changeset).did
    end

    test "validates following and followed_by format" do
      valid_attrs = %{
        did: "did:plc:1234abcd"
      }

      # No following/followed_by
      changeset = Relationship.changeset(%Relationship{}, valid_attrs)
      assert changeset.valid?

      # Valid following
      changeset =
        Relationship.changeset(
          %Relationship{},
          Map.put(valid_attrs, :following, "at://did:plc:abc123/app.bsky.graph.follow/123")
        )

      assert changeset.valid?

      # Invalid following
      changeset =
        Relationship.changeset(
          %Relationship{},
          Map.put(valid_attrs, :following, "not-an-at-uri")
        )

      refute changeset.valid?
      assert "must be an AT-URI" in errors_on(changeset).following

      # Valid followed_by
      changeset =
        Relationship.changeset(
          %Relationship{},
          Map.put(valid_attrs, :followed_by, "at://did:plc:def456/app.bsky.graph.follow/456")
        )

      assert changeset.valid?

      # Invalid followed_by
      changeset =
        Relationship.changeset(
          %Relationship{},
          Map.put(valid_attrs, :followed_by, "not-an-at-uri")
        )

      refute changeset.valid?
      assert "must be an AT-URI" in errors_on(changeset).followed_by
    end
  end

  describe "new/1" do
    test "creates a valid relationship with only DID" do
      did = "did:plc:1234abcd"
      assert {:ok, relationship} = Relationship.new(%{did: did})
      assert relationship.did == did
      assert relationship.following == nil
      assert relationship.followed_by == nil
    end

    test "creates a valid relationship with all fields" do
      did = "did:plc:1234abcd"
      following = "at://did:plc:abc123/app.bsky.graph.follow/123"
      followed_by = "at://did:plc:def456/app.bsky.graph.follow/456"

      assert {:ok, relationship} =
               Relationship.new(%{
                 did: did,
                 following: following,
                 followed_by: followed_by
               })

      assert relationship.did == did
      assert relationship.following == following
      assert relationship.followed_by == followed_by
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Relationship.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid relationship" do
      did = "did:plc:1234abcd"
      assert %Relationship{} = relationship = Relationship.new!(%{did: did})
      assert relationship.did == did
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid relationship/, fn ->
        Relationship.new!(%{})
      end
    end
  end
end
