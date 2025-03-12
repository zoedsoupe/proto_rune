defmodule Lexicon.App.Bsky.Feed.ReasonRepost do
  @moduledoc """
  Information about why a post is in the feed (repost).

  NSID: app.bsky.feed.defs#reasonRepost
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    by: map(), # app.bsky.actor.defs#profileViewBasic
    indexed_at: DateTime.t()
  }

  @primary_key false
  embedded_schema do
    field :by, :map # Reference to app.bsky.actor.defs#profileViewBasic
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a repost reason.
  """
  def changeset(reason_repost, attrs) do
    reason_repost
    |> cast(attrs, [:by, :indexed_at])
    |> validate_required([:by, :indexed_at])
  end

  @doc """
  Validates a repost reason structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end