defmodule Lexicon.App.Bsky.Feed.Defs.PostView do
  @moduledoc """
  A view of a post.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          author: map(),
          record: map(),
          embed: map() | nil,
          reply_count: integer() | nil,
          repost_count: integer() | nil,
          like_count: integer() | nil,
          quote_count: integer() | nil,
          indexed_at: DateTime.t(),
          viewer: map() | nil,
          labels: [map()] | nil,
          threadgate: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    # Reference to app.bsky.actor.defs#profileViewBasic
    field :author, :map
    field :record, :map
    # Union type of various embeds
    field :embed, :map
    field :reply_count, :integer
    field :repost_count, :integer
    field :like_count, :integer
    field :quote_count, :integer
    field :indexed_at, :utc_datetime
    # Reference to #viewerState
    field :viewer, :map
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Reference to #threadgateView
    field :threadgate, :map
  end

  @doc """
  Creates a changeset for validating a post view.
  """
  def changeset(post_view, attrs) do
    post_view
    |> cast(attrs, [
      :uri,
      :cid,
      :author,
      :record,
      :embed,
      :reply_count,
      :repost_count,
      :like_count,
      :quote_count,
      :indexed_at,
      :viewer,
      :labels,
      :threadgate
    ])
    |> validate_required([:uri, :cid, :author, :record, :indexed_at])
  end

  @doc """
  Validates a post view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
