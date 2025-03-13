defmodule Lexicon.App.Bsky.Feed.BlockedAuthor do
  @moduledoc """
  Information about a blocked author.

  NSID: app.bsky.feed.defs#blockedAuthor
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t(),
          # app.bsky.actor.defs#viewerState
          viewer: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :did, :string
    # Reference to app.bsky.actor.defs#viewerState
    field :viewer, :map
  end

  @doc """
  Creates a changeset for validating a blocked author.
  """
  def changeset(blocked_author, attrs) do
    blocked_author
    |> cast(attrs, [:did, :viewer])
    |> validate_required([:did])
    |> validate_format(:did, ~r/^did:/)
  end

  @doc """
  Validates a blocked author structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
