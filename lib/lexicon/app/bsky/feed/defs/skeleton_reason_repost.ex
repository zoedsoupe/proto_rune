defmodule Lexicon.App.Bsky.Feed.Defs.SkeletonReasonRepost do
  @moduledoc """
  Skeleton reason indicating a post appears because it was reposted.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          repost: String.t()
        }

  @primary_key false
  embedded_schema do
    field :repost, :string
  end

  @doc """
  Creates a changeset for validating a skeleton reason repost.
  """
  def changeset(skeleton_reason_repost, attrs) do
    skeleton_reason_repost
    |> cast(attrs, [:repost])
    |> validate_required([:repost])
    |> validate_format(:repost, ~r/^at:\/\//, message: "must be an AT URI")
  end

  @doc """
  Creates a new skeleton reason repost with the given repost URI.
  """
  def new(repost_uri) when is_binary(repost_uri) do
    %__MODULE__{}
    |> changeset(%{repost: repost_uri})
    |> apply_action(:insert)
  end

  @doc """
  Validates a skeleton reason repost structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
