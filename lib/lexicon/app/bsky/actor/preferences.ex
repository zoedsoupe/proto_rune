defmodule Lexicon.App.Bsky.Actor.Preferences do
  @moduledoc """
  Handles the validation of actor preferences.

  Part of app.bsky.actor lexicon.
  """

  alias Lexicon.App.Bsky.Actor.AdultContentPref
  alias Lexicon.App.Bsky.Actor.BskyAppStatePref
  alias Lexicon.App.Bsky.Actor.ContentLabelPref
  alias Lexicon.App.Bsky.Actor.FeedViewPref
  alias Lexicon.App.Bsky.Actor.HiddenPostsPref
  alias Lexicon.App.Bsky.Actor.InterestsPref
  alias Lexicon.App.Bsky.Actor.LabelersPref
  alias Lexicon.App.Bsky.Actor.MutedWordsPref
  alias Lexicon.App.Bsky.Actor.PersonalDetailsPref
  alias Lexicon.App.Bsky.Actor.PostInteractionSettingsPref
  alias Lexicon.App.Bsky.Actor.SavedFeedsPref
  alias Lexicon.App.Bsky.Actor.SavedFeedsPrefV2
  alias Lexicon.App.Bsky.Actor.ThreadViewPref
  alias Lexicon.App.Bsky.Actor.VerificationPrefs

  @doc """
  Validates a preference item based on its type.
  """
  def validate_preference_item(item) when is_map(item) do
    validate_simple_preferences(item) || validate_complex_preferences(item)
  end

  # Handle simple preferences that can be identified by key presence
  defp validate_simple_preferences(item) do
    validate_by_key(item)
  end

  # Validate preferences based on key presence - split into two to reduce complexity
  defp validate_by_key(item) do
    cond do
      has_field?(item, "enabled") ->
        AdultContentPref.validate(item)

      has_fields?(item, ["visibility", "label"]) ->
        ContentLabelPref.validate(item)

      has_fields?(item, ["pinned", "saved"]) ->
        SavedFeedsPref.validate(item)

      has_field?(item, "birth_date") ->
        PersonalDetailsPref.validate(item)

      has_field?(item, "feed") ->
        FeedViewPref.validate(item)

      true ->
        validate_by_key_part2(item)
    end
  end

  defp validate_by_key_part2(item) do
    cond do
      has_field?(item, "sort") ->
        ThreadViewPref.validate(item)

      has_field?(item, "tags") ->
        InterestsPref.validate(item)

      has_field?(item, "active_progress_guide") ->
        BskyAppStatePref.validate(item)

      has_field?(item, "threadgate_allow_rules") ->
        PostInteractionSettingsPref.validate(item)

      has_field?(item, "hide_badges") ->
        VerificationPrefs.validate(item)

      true ->
        nil
    end
  end

  # Handle complex preferences that need additional logic
  defp validate_complex_preferences(item) do
    if has_field?(item, "items") do
      validate_items_preference(item)
    else
      {:error, :unknown_preference_type}
    end
  end

  # Helper to check if a map has a specific field
  defp has_field?(map, field) when is_map(map), do: Map.has_key?(map, field)

  # Helper to check if a map has all fields in a list
  defp has_fields?(map, fields) when is_map(map) and is_list(fields) do
    Enum.all?(fields, fn field -> Map.has_key?(map, field) end)
  end

  # Separate function to handle the complex "items" type cases
  defp validate_items_preference(%{"items" => items} = item) when is_list(items) do
    cond do
      Enum.any?(items, &has_saved_feeds_properties?/1) ->
        SavedFeedsPrefV2.validate(item)

      Enum.any?(items, &has_field?(&1, "value")) ->
        MutedWordsPref.validate(item)

      Enum.any?(items, &is_binary/1) ->
        HiddenPostsPref.validate(item)

      Enum.any?(items, &has_field?(&1, "did")) ->
        LabelersPref.validate(item)

      true ->
        {:error, :unknown_preference_type}
    end
  end

  # Helper to identify saved feeds properties
  defp has_saved_feeds_properties?(item) when is_map(item) do
    has_field?(item, "value")
  end

  @doc """
  Validates an array of preference items.
  """
  def validate(preferences) when is_list(preferences) do
    preferences
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case validate_preference_item(item) do
        {:ok, validated} -> {:cont, {:ok, [validated | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  def validate(_), do: {:error, :invalid_preferences}
end
