defmodule Lexicon.App.Bsky.Actor.Defs.KnownFollowers do
  @moduledoc """
  The subject's followers whom you also follow.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          count: integer(),
          followers: [map()]
        }

  @primary_key false
  embedded_schema do
    field :count, :integer
    # Array of #profileViewBasic
    field :followers, {:array, :map}
  end

  @doc """
  Creates a changeset for validating known followers information.
  """
  def changeset(known_followers, attrs) do
    known_followers
    |> cast(attrs, [:count, :followers])
    |> validate_required([:count, :followers])
    |> validate_length(:followers, max: 5)
  end

  @doc """
  Validates known followers information structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
