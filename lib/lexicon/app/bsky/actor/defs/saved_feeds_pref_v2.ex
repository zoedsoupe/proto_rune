defmodule Lexicon.App.Bsky.Actor.Defs.SavedFeedsPrefV2 do
  @moduledoc """
  Preferences for saved feeds (v2).

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.Defs.SavedFeed

  @type t :: %__MODULE__{
          items: [SavedFeed.t()]
        }

  @primary_key false
  embedded_schema do
    embeds_many :items, SavedFeed
  end

  @doc """
  Creates a changeset for validating saved feeds preferences (v2).
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [])
    |> cast_embed(:items, required: true)
  end

  @doc """
  Validates a saved feeds preferences (v2) structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
