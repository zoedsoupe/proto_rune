defmodule Lexicon.App.Bsky.Actor.KnownFollowers do
  @moduledoc """
  The subject's followers whom the viewer also follows.

  NSID: app.bsky.actor.defs#knownFollowers
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          count: integer(),
          # Array of ProfileViewBasic
          followers: [map()]
        }

  @primary_key false
  embedded_schema do
    field :count, :integer
    # Array of ProfileViewBasic
    field :followers, {:array, :map}
  end

  @doc """
  Creates a changeset for validating known followers.
  """
  def changeset(known_followers, attrs) do
    known_followers
    |> cast(attrs, [:count, :followers])
    |> validate_required([:count, :followers])
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> validate_length(:followers, max: 5)
  end

  @doc """
  Validates a known followers structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
