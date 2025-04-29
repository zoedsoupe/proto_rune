defmodule Lexicon.App.Bsky.Actor.LabelersPref do
  @moduledoc """
  Preferences for labelers.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.LabelerPrefItem

  @type t :: %__MODULE__{
          labelers: [LabelerPrefItem.t()]
        }

  @primary_key false
  embedded_schema do
    embeds_many :labelers, LabelerPrefItem
  end

  @doc """
  Creates a changeset for validating labelers preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [])
    |> cast_embed(:labelers, required: true)
  end

  @doc """
  Validates a labelers preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
