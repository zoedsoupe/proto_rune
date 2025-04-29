defmodule Lexicon.App.Bsky.Feed.Defs.BlockedPost do
  @moduledoc """
  Represents a post that has been blocked.

  Part of app.bsky.feed.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          blocked: boolean(),
          author: map()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :blocked, :boolean, default: true
    # Reference to #blockedAuthor
    field :author, :map
  end

  @doc """
  Creates a changeset for validating a blocked post.
  """
  def changeset(blocked_post, attrs) do
    blocked_post
    |> cast(attrs, [:uri, :blocked, :author])
    |> validate_required([:uri, :blocked, :author])
    |> validate_blocked()
  end

  defp validate_blocked(changeset) do
    if get_field(changeset, :blocked) do
      changeset
    else
      add_error(changeset, :blocked, "must be true")
    end
  end

  @doc """
  Creates a new blocked post with the given URI and author.
  """
  def new(uri, author) when is_binary(uri) and is_map(author) do
    %__MODULE__{uri: uri, blocked: true, author: author}
  end

  @doc """
  Validates a blocked post structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
