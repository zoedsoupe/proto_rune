defmodule Lexicon.App.Bsky.Feed.Defs.FeedViewPost do
  @moduledoc """
  A feed post view with additional context.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          post: map(),
          reply: map() | nil,
          reason: map() | nil,
          feed_context: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    # Reference to #postView
    field :post, :map
    # Reference to #replyRef
    field :reply, :map
    # Union of #reasonRepost and #reasonPin
    field :reason, :map
    field :feed_context, :string
  end

  @doc """
  Creates a changeset for validating a feed view post.
  """
  def changeset(feed_view_post, attrs) do
    feed_view_post
    |> cast(attrs, [:post, :reply, :reason, :feed_context])
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
