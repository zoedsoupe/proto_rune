defmodule Lexicon.App.Bsky.Embed.AspectRatio do
  @moduledoc """
  Represents an aspect ratio (width:height).
  It may be approximate, and may not correspond to absolute dimensions in any given unit.

  NSID: app.bsky.embed.defs#aspectRatio
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          width: integer(),
          height: integer()
        }

  @primary_key false
  embedded_schema do
    field :width, :integer
    field :height, :integer
  end

  @doc """
  Creates a changeset for validating an aspect ratio.
  """
  def changeset(aspect_ratio, attrs) do
    aspect_ratio
    |> cast(attrs, [:width, :height])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end

  @doc """
  Creates a new aspect ratio with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new aspect ratio, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, aspect_ratio} -> aspect_ratio
      {:error, changeset} -> raise "Invalid aspect ratio: #{inspect(changeset.errors)}"
    end
  end
end
