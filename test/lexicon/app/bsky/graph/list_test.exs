defmodule Lexicon.App.Bsky.Graph.ListTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.List

  describe "changeset/2" do
    test "validates required fields" do
      changeset = List.changeset(%List{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).purpose
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates name length" do
      # Valid name
      changeset =
        List.changeset(%List{}, %{
          name: "My List",
          purpose: "app.bsky.graph.defs#modlist",
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Empty name
      changeset =
        List.changeset(%List{}, %{
          name: "",
          purpose: "app.bsky.graph.defs#modlist",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      # This gets caught by validation_required as we don't reach validate_length
      assert "can't be blank" in errors_on(changeset).name

      # Name too long
      too_long_name = String.duplicate("x", 65)

      changeset =
        List.changeset(%List{}, %{
          name: too_long_name,
          purpose: "app.bsky.graph.defs#modlist",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "should be at most 64 character(s)" in errors_on(changeset).name
    end

    test "validates purpose" do
      # Valid purposes
      for purpose <- [
            "app.bsky.graph.defs#modlist",
            "app.bsky.graph.defs#curatelist",
            "app.bsky.graph.defs#referencelist"
          ] do
        changeset =
          List.changeset(%List{}, %{
            name: "My List",
            purpose: purpose,
            created_at: DateTime.utc_now()
          })

        assert changeset.valid?
      end

      # Invalid purpose
      changeset =
        List.changeset(%List{}, %{
          name: "My List",
          purpose: "invalid_purpose",
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "invalid purpose" in errors_on(changeset).purpose
    end

    test "validates description length and graphemes" do
      valid_attrs = %{
        name: "My List",
        purpose: "app.bsky.graph.defs#modlist",
        created_at: DateTime.utc_now()
      }

      # Valid description
      changeset = List.changeset(%List{}, Map.put(valid_attrs, :description, "A nice description"))
      assert changeset.valid?

      # Description too long (characters)
      too_long_desc = String.duplicate("x", 3001)
      changeset = List.changeset(%List{}, Map.put(valid_attrs, :description, too_long_desc))
      refute changeset.valid?
      assert "should be at most 3000 character(s)" in errors_on(changeset).description

      # Description too long (graphemes)
      too_many_graphemes = String.duplicate("🚀", 301)
      changeset = List.changeset(%List{}, Map.put(valid_attrs, :description, too_many_graphemes))
      refute changeset.valid?
      assert "should have at most 300 graphemes" in errors_on(changeset).description
    end
  end

  describe "new/1" do
    test "creates a valid list" do
      assert {:ok, list} =
               List.new(%{
                 name: "My List",
                 purpose: "app.bsky.graph.defs#modlist"
               })

      assert list.name == "My List"
      assert list.purpose == "app.bsky.graph.defs#modlist"
      assert %DateTime{} = list.created_at
    end

    test "creates a list with optional fields" do
      facets = [%{index: %{byte_start: 0, byte_end: 5}, features: ["mention"]}]

      assert {:ok, list} =
               List.new(%{
                 name: "My List",
                 purpose: "app.bsky.graph.defs#curatelist",
                 description: "A nice description",
                 description_facets: facets,
                 created_at: ~U[2023-01-01 00:00:00Z]
               })

      assert list.name == "My List"
      assert list.purpose == "app.bsky.graph.defs#curatelist"
      assert list.description == "A nice description"
      assert list.description_facets == facets
      assert list.created_at == ~U[2023-01-01 00:00:00Z]
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = List.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid list" do
      assert %List{} =
               list =
               List.new!(%{
                 name: "My List",
                 purpose: "app.bsky.graph.defs#modlist"
               })

      assert list.name == "My List"
      assert list.purpose == "app.bsky.graph.defs#modlist"
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid list/, fn ->
        List.new!(%{})
      end
    end
  end
end
