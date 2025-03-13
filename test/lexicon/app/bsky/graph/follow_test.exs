defmodule Lexicon.App.Bsky.Graph.FollowTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.Follow

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Follow.changeset(%Follow{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subject
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates subject format" do
      # Valid DID
      changeset =
        Follow.changeset(%Follow{}, %{
          subject: "did:plc:1234abcd",
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid subject (not a DID)
      changeset =
        Follow.changeset(%Follow{}, %{
          subject: "not-a-did",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "subject must be a DID" in errors_on(changeset).subject
    end
  end

  describe "new/1" do
    test "creates a valid follow" do
      subject = "did:plc:1234abcd"
      assert {:ok, follow} = Follow.new(%{subject: subject})
      assert follow.subject == subject
      assert %DateTime{} = follow.created_at
    end

    test "creates a follow with custom created_at" do
      subject = "did:plc:1234abcd"
      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, follow} =
               Follow.new(%{
                 subject: subject,
                 created_at: created_at
               })

      assert follow.subject == subject
      assert follow.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Follow.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid follow" do
      subject = "did:plc:1234abcd"
      assert %Follow{} = follow = Follow.new!(%{subject: subject})
      assert follow.subject == subject
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid follow/, fn ->
        Follow.new!(%{})
      end
    end
  end
end
