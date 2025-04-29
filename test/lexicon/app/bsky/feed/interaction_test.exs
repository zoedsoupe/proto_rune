defmodule Lexicon.App.Bsky.Feed.InteractionTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Feed
  alias Lexicon.App.Bsky.Feed.Interaction

  describe "changeset/2" do
    test "validates item format" do
      # Valid AT URI
      valid_attrs = %{item: "at://did:plc:1234/app.bsky.feed.post/1234"}
      changeset = Interaction.changeset(%Interaction{}, valid_attrs)
      assert changeset.valid?

      # Invalid format
      invalid_attrs = %{item: "invalid:uri"}
      changeset = Interaction.changeset(%Interaction{}, invalid_attrs)
      refute changeset.valid?
      assert "must be an AT URI" in errors_on(changeset).item
    end

    test "validates event value" do
      base_attrs = %{item: "at://did:plc:1234/app.bsky.feed.post/1234"}

      # Valid event
      valid_attrs = Map.put(base_attrs, :event, Feed.interaction_like())
      changeset = Interaction.changeset(%Interaction{}, valid_attrs)
      assert changeset.valid?

      # Invalid event
      invalid_attrs = Map.put(base_attrs, :event, "invalid-event")
      changeset = Interaction.changeset(%Interaction{}, invalid_attrs)
      refute changeset.valid?
      assert "has invalid value" in errors_on(changeset).event
    end

    test "validates feed_context length" do
      base_attrs = %{item: "at://did:plc:1234/app.bsky.feed.post/1234"}

      # Valid length
      valid_attrs = Map.put(base_attrs, :feed_context, String.duplicate("a", 2000))
      changeset = Interaction.changeset(%Interaction{}, valid_attrs)
      assert changeset.valid?

      # Too long
      invalid_attrs = Map.put(base_attrs, :feed_context, String.duplicate("a", 2001))
      changeset = Interaction.changeset(%Interaction{}, invalid_attrs)
      refute changeset.valid?
      assert "should be at most 2000 character(s)" in errors_on(changeset).feed_context
    end
  end

  describe "new/1" do
    test "creates a new interaction with valid attributes" do
      attrs = %{
        item: "at://did:plc:1234/app.bsky.feed.post/1234",
        event: Feed.interaction_like(),
        feed_context: "home"
      }

      assert {:ok, interaction} = Interaction.new(attrs)
      assert interaction.item == attrs.item
      assert interaction.event == attrs.event
      assert interaction.feed_context == attrs.feed_context
    end

    test "returns error with invalid attributes" do
      attrs = %{item: "invalid:uri"}
      assert {:error, changeset} = Interaction.new(attrs)
      refute changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        item: "at://did:plc:1234/app.bsky.feed.post/1234",
        event: Feed.interaction_like(),
        feed_context: "home"
      }

      assert {:ok, interaction} = Interaction.validate(valid_map)
      assert interaction.item == valid_map.item
      assert interaction.event == valid_map.event
      assert interaction.feed_context == valid_map.feed_context
    end

    test "returns error with invalid data" do
      invalid_map = %{item: "invalid:uri"}
      assert {:error, changeset} = Interaction.validate(invalid_map)
      refute changeset.valid?
    end
  end

  # Helper functions
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
