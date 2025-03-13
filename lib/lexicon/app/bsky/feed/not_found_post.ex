defmodule Lexicon.App.Bsky.Feed.NotFoundPost do
  @moduledoc """
  Reference to a post that was not found.

  NSID: app.bsky.feed.defs#notFoundPost
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          not_found: boolean()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :not_found, :boolean, default: true
  end

  @doc """
  Creates a changeset for validating a not found post.
  """
  def changeset(not_found_post, attrs) do
    not_found_post
    |> cast(attrs, [:uri, :not_found])
    |> validate_required([:uri, :not_found])
    |> validate_format(:uri, ~r/^at:/, message: "must be an AT URI")
  end

  @doc """
  Validates a not found post structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
