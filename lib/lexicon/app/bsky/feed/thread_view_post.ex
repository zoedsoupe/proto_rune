defmodule Lexicon.App.Bsky.Feed.ThreadViewPost do
  @moduledoc """
  A thread post view, includes information about the post and its context in the thread.

  NSID: app.bsky.feed.defs#threadViewPost
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Feed.PostView
  alias Lexicon.App.Bsky.Feed.ThreadContext

  # Union of ThreadViewPost, NotFoundPost, or BlockedPost
  @type parent_union :: map()
  # Union of ThreadViewPost, NotFoundPost, or BlockedPost
  @type replies_union :: map()
  @type t :: %__MODULE__{
          post: PostView.t(),
          parent: parent_union() | nil,
          replies: [replies_union()] | nil,
          thread_context: ThreadContext.t() | nil
        }

  @primary_key false
  embedded_schema do
    embeds_one :post, PostView
    # Union of ThreadViewPost, NotFoundPost, or BlockedPost
    field :parent, :map
    # Array of ThreadViewPost, NotFoundPost, or BlockedPost
    field :replies, {:array, :map}
    embeds_one :thread_context, ThreadContext
  end

  @doc """
  Creates a changeset for validating a thread view post.
  """
  def changeset(thread_view_post, attrs) do
    thread_view_post
    |> cast(attrs, [:parent, :replies])
    |> cast_embed(:post)
    |> cast_embed(:thread_context)
    |> validate_required([:post])
  end

  @doc """
  Validates a thread view post structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
