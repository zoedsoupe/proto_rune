defmodule Lexicon.App.Bsky.Feed.Defs.ViewerState do
  @moduledoc """
  The state of the post from the viewer's perspective.

  Part of app.bsky.feed.defs lexicon.
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
    field :repost, :string
    field :like, :string
    field :thread_muted, :boolean
    field :reply_disabled, :boolean
    field :embedding_disabled, :boolean
    field :pinned, :boolean
  end

  @doc """
  Creates a changeset for validating a viewer state.
  """
  def changeset(viewer_state, attrs) do
    cast(viewer_state, attrs, [:repost, :like, :thread_muted, :reply_disabled, :embedding_disabled, :pinned])
  end

  @doc """
  Validates a viewer state structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
