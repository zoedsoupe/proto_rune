defmodule Lexicon.App.Bsky.Feed.BlockedPost do
  @moduledoc """
  Reference to a post that has been blocked.

  NSID: app.bsky.feed.defs#blockedPost
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Lexicon.App.Bsky.Feed.BlockedAuthor

  @type t :: %__MODULE__{
    uri: String.t(),
    blocked: boolean(),
    author: BlockedAuthor.t()
  }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :blocked, :boolean, default: true
    embeds_one :author, BlockedAuthor
  end

  @doc """
  Creates a changeset for validating a blocked post.
  """
  def changeset(blocked_post, attrs) do
    blocked_post
    |> cast(attrs, [:uri, :blocked])
    |> cast_embed(:author)
    |> validate_required([:uri, :blocked, :author])
    |> validate_format(:uri, ~r/^at:/, message: "must be an AT URI")
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