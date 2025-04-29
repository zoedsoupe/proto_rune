defmodule Lexicon.App.Bsky.Unspecced.Defs.TrendingTopic do
  @moduledoc """
  A trending topic.

  Part of app.bsky.unspecced.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          topic: String.t(),
          display_name: String.t() | nil,
          description: String.t() | nil,
          link: String.t()
        }

  @primary_key false
  embedded_schema do
    field :topic, :string
    field :display_name, :string
    field :description, :string
    field :link, :string
  end

  @doc """
  Creates a changeset for validating a trending topic.
  """
  def changeset(trending_topic, attrs) do
    trending_topic
    |> cast(attrs, [:topic, :display_name, :description, :link])
    |> validate_required([:topic, :link])
  end

  @doc """
  Validates a trending topic structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
