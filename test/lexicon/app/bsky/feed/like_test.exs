defmodule Lexicon.App.Bsky.Feed.LikeTest do
  use ProtoRune.DataCase
  
  alias Lexicon.App.Bsky.Feed.Like

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Like.changeset(%Like{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subject
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates subject structure" do
      # Valid subject
      valid_subject = %{uri: "at://did:plc:1234/post/1", cid: "bafyrei..."}
      changeset = Like.changeset(%Like{}, %{
        subject: valid_subject,
        created_at: DateTime.utc_now()
      })
      assert changeset.valid?

      # Invalid subject (not a map)
      changeset = Like.changeset(%Like{}, %{
        subject: "not-a-map",
        created_at: DateTime.utc_now()
      })
      refute changeset.valid?
      assert errors_on(changeset).subject # Just check that there's an error

      # Invalid subject (missing URI)
      changeset = Like.changeset(%Like{}, %{
        subject: %{cid: "bafyrei..."},
        created_at: DateTime.utc_now()
      })
      refute changeset.valid?
      assert "must have a URI" in errors_on(changeset).subject

      # Invalid subject (missing CID)
      changeset = Like.changeset(%Like{}, %{
        subject: %{uri: "at://did:plc:1234/post/1"},
        created_at: DateTime.utc_now()
      })
      refute changeset.valid?
      assert "must have a CID" in errors_on(changeset).subject
    end
  end

  describe "new/1" do
    test "creates a valid like" do
      subject = %{uri: "at://did:plc:1234/post/1", cid: "bafyrei..."}
      assert {:ok, like} = Like.new(%{subject: subject})
      assert like.subject == subject
      assert %DateTime{} = like.created_at
    end

    test "creates a like with custom created_at" do
      subject = %{uri: "at://did:plc:1234/post/1", cid: "bafyrei..."}
      created_at = DateTime.utc_now() |> DateTime.truncate(:second)
      assert {:ok, like} = Like.new(%{
        subject: subject,
        created_at: created_at
      })
      assert like.subject == subject
      assert like.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Like.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid like" do
      subject = %{uri: "at://did:plc:1234/post/1", cid: "bafyrei..."}
      assert %Like{} = like = Like.new!(%{subject: subject})
      assert like.subject == subject
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid like/, fn ->
        Like.new!(%{})
      end
    end
  end
end