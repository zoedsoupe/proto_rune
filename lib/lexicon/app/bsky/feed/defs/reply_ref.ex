defmodule Lexicon.App.Bsky.Feed.Defs.ReplyRef do
  @moduledoc """
  References to parent and root posts in a reply.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          root: map(),
          parent: map(),
          grandparent_author: map() | nil
        }

  @primary_key false
  embedded_schema do
    # Union of #postView, #notFoundPost, #blockedPost
    field :root, :map
    # Union of #postView, #notFoundPost, #blockedPost
    field :parent, :map
    # Reference to app.bsky.actor.defs#profileViewBasic
    field :grandparent_author, :map
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
