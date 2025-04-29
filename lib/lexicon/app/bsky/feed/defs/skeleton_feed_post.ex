defmodule Lexicon.App.Bsky.Feed.Defs.SkeletonFeedPost do
  @moduledoc """
  A skeleton representation of a feed post (URI only).

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          post: String.t(),
          reason: map() | nil,
          feed_context: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :post, :string
    # Union of #skeletonReasonRepost and #skeletonReasonPin
    field :reason, :map
    field :feed_context, :string
  end

  @doc """
  Creates a changeset for validating a skeleton feed post.
  """
  def changeset(skeleton_feed_post, attrs) do
    skeleton_feed_post
    |> cast(attrs, [:post, :reason, :feed_context])
    |> validate_required([:post])
    |> validate_format(:post, ~r/^at:\/\//, message: "must be an AT URI")
    |> validate_length(:feed_context, max: 2000)
  end

  @doc """
  Creates a new skeleton feed post with the given post URI.
  """
  def new(post_uri, reason \\ nil, feed_context \\ nil) when is_binary(post_uri) do
    attrs = %{
      post: post_uri,
      reason: reason,
      feed_context: feed_context
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Validates a skeleton feed post structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
