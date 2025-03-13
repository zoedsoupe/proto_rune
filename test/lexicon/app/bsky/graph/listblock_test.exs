defmodule Lexicon.App.Bsky.Graph.ListblockTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.Listblock

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Listblock.changeset(%Listblock{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subject
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates subject format" do
      # Valid AT-URI
      changeset =
        Listblock.changeset(%Listblock{}, %{
          subject: "at://did:plc:abc123/app.bsky.graph.list/123",
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid subject (not an AT-URI)
      changeset =
        Listblock.changeset(%Listblock{}, %{
          subject: "not-an-at-uri",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "subject must be an AT-URI" in errors_on(changeset).subject
    end
  end

  describe "new/1" do
    test "creates a valid list block" do
      subject = "at://did:plc:abc123/app.bsky.graph.list/123"

      assert {:ok, listblock} = Listblock.new(%{subject: subject})
      assert listblock.subject == subject
      assert %DateTime{} = listblock.created_at
    end

    test "creates a list block with custom created_at" do
      subject = "at://did:plc:abc123/app.bsky.graph.list/123"
      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, listblock} =
               Listblock.new(%{
                 subject: subject,
                 created_at: created_at
               })

      assert listblock.subject == subject
      assert listblock.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Listblock.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid list block" do
      subject = "at://did:plc:abc123/app.bsky.graph.list/123"

      assert %Listblock{} = listblock = Listblock.new!(%{subject: subject})
      assert listblock.subject == subject
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid list block/, fn ->
        Listblock.new!(%{})
      end
    end
  end
end
