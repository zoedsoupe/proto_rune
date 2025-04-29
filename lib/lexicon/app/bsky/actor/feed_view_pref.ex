defmodule Lexicon.App.Bsky.Actor.FeedViewPref do
  @moduledoc """
  Preferences for feed view.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          feed: String.t(),
          hide_replies: boolean() | nil,
          hide_replies_by_unfollowed: boolean() | nil,
          hide_replies_by_like_count: integer() | nil,
          hide_reposts: boolean() | nil,
          hide_quote_posts: boolean() | nil
        }

  @primary_key false
  embedded_schema do
    field :feed, :string
    field :hide_replies, :boolean
    field :hide_replies_by_unfollowed, :boolean, default: true
    field :hide_replies_by_like_count, :integer
    field :hide_reposts, :boolean
    field :hide_quote_posts, :boolean
  end

  @doc """
  Creates a changeset for validating feed view preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [
      :feed,
      :hide_replies,
      :hide_replies_by_unfollowed,
      :hide_replies_by_like_count,
      :hide_reposts,
      :hide_quote_posts
    ])
    |> validate_required([:feed])
  end

  @doc """
  Validates a feed view preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
