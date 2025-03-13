defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchPost do
  @moduledoc """
  Skeleton of a search post result.

  NSID: app.bsky.unspecced.defs#skeletonSearchPost
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
  Creates a changeset for validating a skeleton search post.
  """
  def changeset(skeleton, attrs) do
    skeleton
    |> cast(attrs, [:uri])
    |> validate_required([:uri])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be a valid AT-URI")
  end

  @doc """
  Creates a new skeleton search post with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new skeleton search post, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, skeleton} -> skeleton
      {:error, changeset} -> raise "Invalid skeleton search post: #{inspect(changeset.errors)}"
    end
  end
end
