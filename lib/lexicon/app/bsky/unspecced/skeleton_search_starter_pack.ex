defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchStarterPack do
  @moduledoc """
  Skeleton of a search starter pack result.

  NSID: app.bsky.unspecced.defs#skeletonSearchStarterPack
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
  end

  @doc """
  Creates a changeset for validating a skeleton search starter pack.
  """
  def changeset(skeleton, attrs) do
    skeleton
    |> cast(attrs, [:uri])
    |> validate_required([:uri])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be a valid AT-URI")
  end

  @doc """
  Creates a new skeleton search starter pack with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new skeleton search starter pack, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, skeleton} -> skeleton
      {:error, changeset} -> raise "Invalid skeleton search starter pack: #{inspect(changeset.errors)}"
    end
  end
end
