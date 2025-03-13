defmodule Lexicon.App.Bsky.Feed.FeedViewPost do
  @moduledoc """
  A feed post view, includes information about the post and its context in the feed.

  NSID: app.bsky.feed.defs#feedViewPost
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Feed.PostView
  alias Lexicon.App.Bsky.Feed.ReplyRef

  # Union of ReasonRepost or ReasonPin
  @type reason_union :: map()
  @type t :: %__MODULE__{
          post: PostView.t(),
          reply: ReplyRef.t() | nil,
          reason: reason_union() | nil,
          feed_context: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    embeds_one :post, PostView
    embeds_one :reply, ReplyRef
    # Union of ReasonRepost or ReasonPin
    field :reason, :map
    field :feed_context, :string
  end

  @doc """
  Creates a changeset for validating a feed view post.
  """
  def changeset(feed_view_post, attrs) do
    feed_view_post
    |> cast(attrs, [:reason, :feed_context])
    |> cast_embed(:post)
    |> cast_embed(:reply)
    |> validate_required([:post])
    |> validate_length(:feed_context, max: 2000)
  end

  @doc """
  Validates a feed view post structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
