defmodule Lexicon.App.Bsky.Feed.PostView do
  @moduledoc """
  A view of a post in a feed or thread.

  NSID: app.bsky.feed.defs#postView
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Feed.ViewerState

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          # app.bsky.actor.defs#profileViewBasic
          author: map(),
          record: map(),
          embed: map() | nil,
          reply_count: integer() | nil,
          repost_count: integer() | nil,
          like_count: integer() | nil,
          quote_count: integer() | nil,
          indexed_at: DateTime.t(),
          viewer: ViewerState.t() | nil,
          labels: [map()] | nil,
          # app.bsky.feed.defs#threadgateView
          threadgate: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    # Reference to app.bsky.actor.defs#profileViewBasic
    field :author, :map
    field :record, :map
    # Union of various embed views
    field :embed, :map
    field :reply_count, :integer
    field :repost_count, :integer
    field :like_count, :integer
    field :quote_count, :integer
    field :indexed_at, :utc_datetime
    embeds_one :viewer, ViewerState
    # Reference to com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Reference to app.bsky.feed.defs#threadgateView
    field :threadgate, :map
  end

  @doc """
  Creates a changeset for validating a post view.
  """
  def changeset(post_view, attrs) do
    post_view
    |> cast(attrs, [
      :uri,
      :cid,
      :author,
      :record,
      :embed,
      :reply_count,
      :repost_count,
      :like_count,
      :quote_count,
      :indexed_at,
      :labels,
      :threadgate
    ])
    |> cast_embed(:viewer)
    |> validate_required([:uri, :cid, :author, :record, :indexed_at])
    |> validate_format(:uri, ~r/^at:/, message: "must be an AT URI")
    |> validate_number(:reply_count, greater_than_or_equal_to: 0)
    |> validate_number(:repost_count, greater_than_or_equal_to: 0)
    |> validate_number(:like_count, greater_than_or_equal_to: 0)
    |> validate_number(:quote_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a post view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
