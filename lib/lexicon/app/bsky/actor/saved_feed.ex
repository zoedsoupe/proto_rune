defmodule Lexicon.App.Bsky.Actor.SavedFeed do
  @moduledoc """
  Represents a saved feed.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          value: String.t(),
          pinned: boolean()
        }

  @primary_key false
  embedded_schema do
    field :id, :string
    field :type, :string
    field :value, :string
    field :pinned, :boolean
  end

  # Known values for feed types
  @feed_type_feed "feed"
  @feed_type_list "list"
  @feed_type_timeline "timeline"

  @doc """
  Creates a changeset for validating a saved feed.
  """
  def changeset(saved_feed, attrs) do
    saved_feed
    |> cast(attrs, [:id, :type, :value, :pinned])
    |> validate_required([:id, :type, :value, :pinned])
    |> validate_feed_type()
  end

  defp validate_feed_type(changeset) do
    type = get_field(changeset, :type)

    if type && type not in [@feed_type_feed, @feed_type_list, @feed_type_timeline] do
      add_error(changeset, :type, "must be a valid feed type")
    else
      changeset
    end
  end

  @doc """
  Validates a saved feed structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
