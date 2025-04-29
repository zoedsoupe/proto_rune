defmodule Lexicon.App.Bsky.Feed.Interaction do
  @moduledoc """
  User interaction with a feed item.

  Part of app.bsky.feed lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Feed

  @type t :: %__MODULE__{
          item: String.t() | nil,
          event: String.t() | nil,
          feed_context: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :item, :string
    field :event, :string
    field :feed_context, :string
  end

  @doc """
  Creates a changeset for validating an interaction.
  """
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:item, :event, :feed_context])
    |> validate_format(:item, ~r/^at:\/\//, message: "must be an AT URI")
    |> validate_length(:feed_context, max: 2000)
    |> validate_event()
  end

  defp validate_event(changeset) do
    case get_field(changeset, :event) do
      nil -> changeset
      event -> validate_event_value(changeset, event)
    end
  end

  defp validate_event_value(changeset, event) do
    if Feed.valid_interaction_event?(event) do
      changeset
    else
      add_error(changeset, :event, "has invalid value")
    end
  end

  @doc """
  Creates a new interaction with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Validates an interaction structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
