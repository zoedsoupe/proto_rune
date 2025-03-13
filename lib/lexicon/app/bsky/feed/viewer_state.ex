defmodule Lexicon.App.Bsky.Feed.ViewerState do
  @moduledoc """
  Feed-specific viewer state with information about the requesting account's 
  relationship with a post.

  NSID: app.bsky.feed.defs#viewerState
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          repost: String.t() | nil,
          like: String.t() | nil,
          thread_muted: boolean() | nil,
          reply_disabled: boolean() | nil,
          embedding_disabled: boolean() | nil,
          pinned: boolean() | nil
        }

  @primary_key false
  embedded_schema do
    # format: at-uri
    field :repost, :string
    # format: at-uri
    field :like, :string
    field :thread_muted, :boolean
    field :reply_disabled, :boolean
    field :embedding_disabled, :boolean
    field :pinned, :boolean
  end

  @doc """
  Creates a changeset for validating feed viewer state.
  """
  def changeset(viewer_state, attrs) do
    viewer_state
    |> cast(attrs, [:repost, :like, :thread_muted, :reply_disabled, :embedding_disabled, :pinned])
    |> validate_format(:repost, ~r/^at:/, message: "must be an AT URI")
    |> validate_format(:like, ~r/^at:/, message: "must be an AT URI")
  end

  @doc """
  Validates a feed viewer state structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
