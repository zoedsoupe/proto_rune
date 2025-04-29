defmodule Lexicon.App.Bsky.Actor.MutedWordsPref do
  @moduledoc """
  Preferences for muted words.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.MutedWord

  @type t :: %__MODULE__{
          items: [MutedWord.t()]
        }

  @primary_key false
  embedded_schema do
    embeds_many :items, MutedWord
  end

  @doc """
  Creates a changeset for validating muted words preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [])
    |> cast_embed(:items, required: true)
  end

  @doc """
  Validates a muted words preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
