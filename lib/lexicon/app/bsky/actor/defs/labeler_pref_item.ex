defmodule Lexicon.App.Bsky.Actor.Defs.LabelerPrefItem do
  @moduledoc """
  Preference item for a labeler.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t()
        }

  @primary_key false
  embedded_schema do
    field :did, :string
  end

  @doc """
  Creates a changeset for validating a labeler preference item.
  """
  def changeset(pref_item, attrs) do
    pref_item
    |> cast(attrs, [:did])
    |> validate_required([:did])
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
  end

  @doc """
  Validates a labeler preference item structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
