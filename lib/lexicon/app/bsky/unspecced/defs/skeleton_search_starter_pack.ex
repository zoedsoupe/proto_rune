defmodule Lexicon.App.Bsky.Unspecced.Defs.SkeletonSearchStarterPack do
  @moduledoc """
  A skeleton reference to a starter pack for search.

  Part of app.bsky.unspecced.defs lexicon.
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
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
  end

  @doc """
  Validates a skeleton search starter pack structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
