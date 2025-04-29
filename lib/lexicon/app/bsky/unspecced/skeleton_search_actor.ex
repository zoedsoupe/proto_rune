defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchActor do
  @moduledoc """
  A skeleton reference to an actor for search.

  Part of app.bsky.unspecced lexicon.
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
  Creates a changeset for validating a skeleton search actor.
  """
  def changeset(skeleton, attrs) do
    skeleton
    |> cast(attrs, [:did])
    |> validate_required([:did])
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
  end

  @doc """
  Validates a skeleton search actor structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
