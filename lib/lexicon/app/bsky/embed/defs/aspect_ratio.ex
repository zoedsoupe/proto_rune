defmodule Lexicon.App.Bsky.Embed.Defs.AspectRatio do
  @moduledoc """
  Represents an aspect ratio (width:height). May be approximate.

  Part of app.bsky.embed.defs lexicon.
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
  Validates an aspect ratio structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
