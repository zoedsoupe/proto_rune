defmodule Lexicon.App.Bsky.Graph.StarterpackTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Graph.Starterpack

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Starterpack.changeset(%Starterpack{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).list
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates name length and graphemes" do
      valid_attrs = %{
        list: "at://did:plc:abc123/app.bsky.graph.list/123",
        created_at: DateTime.utc_now()
      }

      # Valid name
      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :name, "My Starter Pack")
        )

      assert changeset.valid?

      # Name too long (characters)
      too_long_name = String.duplicate("x", 501)

      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :name, too_long_name)
        )

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).name

      # Name too long (graphemes)
      too_many_graphemes = String.duplicate("🚀", 51)

      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :name, too_many_graphemes)
        )

      refute changeset.valid?
      assert "should have at most 50 graphemes" in errors_on(changeset).name
    end

    test "validates list format" do
      valid_attrs = %{
        name: "My Starter Pack",
        created_at: DateTime.utc_now()
      }

      # Valid list
      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :list, "at://did:plc:abc123/app.bsky.graph.list/123")
        )

      assert changeset.valid?

      # Invalid list
      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :list, "not-an-at-uri")
        )

      refute changeset.valid?
      assert "list must be an AT-URI" in errors_on(changeset).list
    end

    test "validates feeds" do
      valid_attrs = %{
        name: "My Starter Pack",
        list: "at://did:plc:abc123/app.bsky.graph.list/123",
        created_at: DateTime.utc_now()
      }

      # Valid empty feeds
      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :feeds, [])
        )

      assert changeset.valid?

      # Valid feeds
      valid_feeds = [
        %{uri: "at://did:plc:abc123/app.bsky.feed.generator/123"},
        %{uri: "at://did:plc:def456/app.bsky.feed.generator/456"}
      ]

      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :feeds, valid_feeds)
        )

      assert changeset.valid?

      # Too many feeds
      too_many_feeds = [
        %{uri: "at://did:plc:abc123/app.bsky.feed.generator/1"},
        %{uri: "at://did:plc:abc123/app.bsky.feed.generator/2"},
        %{uri: "at://did:plc:abc123/app.bsky.feed.generator/3"},
        %{uri: "at://did:plc:abc123/app.bsky.feed.generator/4"}
      ]

      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :feeds, too_many_feeds)
        )

      refute changeset.valid?
      assert "cannot have more than 3 feeds" in errors_on(changeset).feeds

      # Invalid feed URI
      invalid_feeds = [
        %{uri: "not-an-at-uri"}
      ]

      changeset =
        Starterpack.changeset(
          %Starterpack{},
          Map.put(valid_attrs, :feeds, invalid_feeds)
        )

      refute changeset.valid?
      assert "feed items must have a valid AT-URI" in errors_on(changeset).feeds
    end
  end

  describe "new/1" do
    test "creates a valid starter pack" do
      list = "at://did:plc:abc123/app.bsky.graph.list/123"

      assert {:ok, starterpack} =
               Starterpack.new(%{
                 name: "My Starter Pack",
                 list: list
               })

      assert starterpack.name == "My Starter Pack"
      assert starterpack.list == list
      assert %DateTime{} = starterpack.created_at
    end

    test "creates a starter pack with optional fields" do
      list = "at://did:plc:abc123/app.bsky.graph.list/123"
      feeds = [%{uri: "at://did:plc:abc123/app.bsky.feed.generator/123"}]
      facets = [%{index: %{byte_start: 0, byte_end: 5}, features: ["mention"]}]
      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, starterpack} =
               Starterpack.new(%{
                 name: "My Starter Pack",
                 description: "A nice starter pack for new users",
                 description_facets: facets,
                 list: list,
                 feeds: feeds,
                 created_at: created_at
               })

      assert starterpack.name == "My Starter Pack"
      assert starterpack.description == "A nice starter pack for new users"
      assert starterpack.description_facets == facets
      assert starterpack.list == list
      assert starterpack.feeds == feeds
      assert starterpack.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Starterpack.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid starter pack" do
      list = "at://did:plc:abc123/app.bsky.graph.list/123"

      assert %Starterpack{} =
               starterpack =
               Starterpack.new!(%{
                 name: "My Starter Pack",
                 list: list
               })

      assert starterpack.name == "My Starter Pack"
      assert starterpack.list == list
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid starter pack/, fn ->
        Starterpack.new!(%{})
      end
    end
  end
end
