defmodule Lexicon.App.Bsky.Feed.Defs.BlockedAuthor do
  @moduledoc """
  Represents an author that has been blocked.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t(),
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
  end

  @doc """
  Creates a new blocked author with the given DID.
  """
  def new(did, viewer \\ nil) when is_binary(did) do
    %__MODULE__{did: did, viewer: viewer}
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
