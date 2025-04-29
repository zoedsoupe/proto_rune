defmodule Lexicon.App.Bsky.Feed.Defs.GeneratorView do
  @moduledoc """
  A view of a feed generator.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Feed.Defs

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          did: String.t(),
          creator: map(),
          display_name: String.t(),
          description: String.t() | nil,
          description_facets: [map()] | nil,
          avatar: String.t() | nil,
          like_count: integer() | nil,
          accepts_interactions: boolean() | nil,
          labels: [map()] | nil,
          viewer: map() | nil,
          content_mode: String.t() | nil,
          indexed_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    field :did, :string
    # Reference to app.bsky.actor.defs#profileView
    field :creator, :map
    field :display_name, :string
    field :description, :string
    # Array of app.bsky.richtext.facet
    field :description_facets, {:array, :map}
    field :avatar, :string
    field :like_count, :integer
    field :accepts_interactions, :boolean
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Reference to #generatorViewerState
    field :viewer, :map
    # One of content mode tokens
    field :content_mode, :string
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a generator view.
  """
  def changeset(generator_view, attrs) do
    generator_view
    |> cast(attrs, [
      :uri,
      :cid,
      :did,
      :creator,
      :display_name,
      :description,
      :description_facets,
      :avatar,
      :like_count,
      :accepts_interactions,
      :labels,
      :viewer,
      :content_mode,
      :indexed_at
    ])
    |> validate_required([:uri, :cid, :did, :creator, :display_name, :indexed_at])
    |> validate_length(:description, max: 3000)
    |> validate_content_mode()
  end

  defp validate_content_mode(changeset) do
    content_mode = get_field(changeset, :content_mode)

    if is_nil(content_mode) or Defs.valid_content_mode?(content_mode) do
      changeset
    else
      add_error(changeset, :content_mode, "has invalid value")
    end
  end

  @doc """
  Validates a generator view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
