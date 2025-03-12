defmodule Lexicon.App.Bsky.Feed.ReplyRef do
  @moduledoc """
  A reference to a post that is being replied to.

  NSID: app.bsky.feed.defs#replyRef
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type post_union :: map() # Union of PostView, NotFoundPost, or BlockedPost
  @type t :: %__MODULE__{
    root: post_union(),
    parent: post_union(),
    grandparent_author: map() | nil # app.bsky.actor.defs#profileViewBasic
  }

  @primary_key false
  embedded_schema do
    field :root, :map # Union of PostView, NotFoundPost, or BlockedPost
    field :parent, :map # Union of PostView, NotFoundPost, or BlockedPost
    field :grandparent_author, :map # Reference to app.bsky.actor.defs#profileViewBasic
  end

  @doc """
  Creates a changeset for validating a reply reference.
  """
  def changeset(reply_ref, attrs) do
    reply_ref
    |> cast(attrs, [:root, :parent, :grandparent_author])
    |> validate_required([:root, :parent])
  end

  @doc """
  Validates a reply reference structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end