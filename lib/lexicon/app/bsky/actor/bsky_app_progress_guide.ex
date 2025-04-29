defmodule Lexicon.App.Bsky.Actor.BskyAppProgressGuide do
  @moduledoc """
  An active progress guide for the Bluesky app.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          guide: String.t()
        }

  @primary_key false
  embedded_schema do
    field :guide, :string
  end

  @doc """
  Creates a changeset for validating a Bluesky app progress guide.
  """
  def changeset(guide, attrs) do
    guide
    |> cast(attrs, [:guide])
    |> validate_required([:guide])
    |> validate_length(:guide, max: 100)
  end

  @doc """
  Validates a Bluesky app progress guide structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
