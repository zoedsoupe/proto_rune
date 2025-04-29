defmodule Lexicon.App.Bsky.Feed.Defs.ThreadViewPost do
  @moduledoc """
  A post in the context of a thread.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          post: map(),
          parent: map() | nil,
          replies: [map()] | nil,
          thread_context: map() | nil
        }

  @primary_key false
  embedded_schema do
    # Reference to #postView
    field :post, :map
    # Union of #threadViewPost, #notFoundPost, #blockedPost
    field :parent, :map
    # Array of union of #threadViewPost, #notFoundPost, #blockedPost
    field :replies, {:array, :map}
    # Reference to #threadContext
    field :thread_context, :map
  end

  @doc """
  Creates a changeset for validating a thread view post.
  """
  def changeset(thread_view_post, attrs) do
    thread_view_post
    |> cast(attrs, [:post, :parent, :replies, :thread_context])
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
