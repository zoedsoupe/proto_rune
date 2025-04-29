defmodule Lexicon.App.Bsky.Actor.Defs.InterestsPref do
  @moduledoc """
  Preferences for user interests.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          tags: [String.t()]
        }

  @primary_key false
  embedded_schema do
    field :tags, {:array, :string}
  end

  @doc """
  Creates a changeset for validating interests preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:tags])
    |> validate_required([:tags])
    |> validate_length(:tags, max: 100)
    |> validate_tag_lengths()
  end

  defp validate_tag_lengths(changeset) do
    tags = get_field(changeset, :tags)

    if tags do
      invalid_tags = Enum.filter(tags, fn tag -> String.length(tag) > 640 end)

      if Enum.empty?(invalid_tags) do
        changeset
      else
        add_error(changeset, :tags, "contains tags that exceed maximum length")
      end
    else
      changeset
    end
  end

  @doc """
  Validates an interests preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
