defmodule Lexicon.App.Bsky.Feed.Defs.ReasonRepost do
  @moduledoc """
  Indicates a post appears because it was reposted.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          by: map(),
          indexed_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    # Reference to app.bsky.actor.defs#profileViewBasic
    field :by, :map
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a reason repost.
  """
  def changeset(reason_repost, attrs) do
    reason_repost
    |> cast(attrs, [:by, :indexed_at])
    |> validate_required([:by, :indexed_at])
  end

  @doc """
  Validates a reason repost structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
