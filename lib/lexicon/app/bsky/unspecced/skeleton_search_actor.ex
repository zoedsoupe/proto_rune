defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchActor do
  @moduledoc """
  Skeleton of a search actor result.

  NSID: app.bsky.unspecced.defs#skeletonSearchActor
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
    |> validate_format(:did, ~r/^did:/, message: "must be a valid DID format")
  end

  @doc """
  Creates a new skeleton search actor with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new skeleton search actor, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, skeleton} -> skeleton
      {:error, changeset} -> raise "Invalid skeleton search actor: #{inspect(changeset.errors)}"
    end
  end
end
