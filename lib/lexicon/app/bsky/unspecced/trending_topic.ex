defmodule Lexicon.App.Bsky.Unspecced.TrendingTopic do
  @moduledoc """
  A trending topic in Bluesky.

  NSID: app.bsky.unspecced.defs#trendingTopic
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
  Creates a new trending topic with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new trending topic, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, trending_topic} -> trending_topic
      {:error, changeset} -> raise "Invalid trending topic: #{inspect(changeset.errors)}"
    end
  end
end
