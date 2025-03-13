defmodule Lexicon.App.Bsky.Graph.ListitemTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.Listitem

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Listitem.changeset(%Listitem{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subject
      assert "can't be blank" in errors_on(changeset).list
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates subject format" do
      # Valid DID
      changeset =
        Listitem.changeset(%Listitem{}, %{
          subject: "did:plc:1234abcd",
          list: "at://did:plc:abc123/app.bsky.graph.list/123",
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid subject (not a DID)
      changeset =
        Listitem.changeset(%Listitem{}, %{
          subject: "not-a-did",
          list: "at://did:plc:abc123/app.bsky.graph.list/123",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "subject must be a DID" in errors_on(changeset).subject
    end

    test "validates list format" do
      # Valid AT-URI
      changeset =
        Listitem.changeset(%Listitem{}, %{
          subject: "did:plc:1234abcd",
          list: "at://did:plc:abc123/app.bsky.graph.list/123",
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid list (not an AT-URI)
      changeset =
        Listitem.changeset(%Listitem{}, %{
          subject: "did:plc:1234abcd",
          list: "not-an-at-uri",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "list must be an AT-URI" in errors_on(changeset).list
    end
  end

  describe "new/1" do
    test "creates a valid list item" do
      subject = "did:plc:1234abcd"
      list = "at://did:plc:abc123/app.bsky.graph.list/123"

      assert {:ok, listitem} =
               Listitem.new(%{
                 subject: subject,
                 list: list
               })

      assert listitem.subject == subject
      assert listitem.list == list
      assert %DateTime{} = listitem.created_at
    end

    test "creates a list item with custom created_at" do
      subject = "did:plc:1234abcd"
      list = "at://did:plc:abc123/app.bsky.graph.list/123"
      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, listitem} =
               Listitem.new(%{
                 subject: subject,
                 list: list,
                 created_at: created_at
               })

      assert listitem.subject == subject
      assert listitem.list == list
      assert listitem.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Listitem.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid list item" do
      subject = "did:plc:1234abcd"
      list = "at://did:plc:abc123/app.bsky.graph.list/123"

      assert %Listitem{} =
               listitem =
               Listitem.new!(%{
                 subject: subject,
                 list: list
               })

      assert listitem.subject == subject
      assert listitem.list == list
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid list item/, fn ->
        Listitem.new!(%{})
      end
    end
  end
end
