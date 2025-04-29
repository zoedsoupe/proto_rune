defmodule Lexicon.App.Bsky.Feed.Defs.NotFoundPost do
  @moduledoc """
  Represents a post that could not be found.

  Part of app.bsky.feed.defs lexicon.
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
    |> validate_not_found()
  end

  defp validate_not_found(changeset) do
    if get_field(changeset, :not_found) do
      changeset
    else
      add_error(changeset, :not_found, "must be true")
    end
  end

  @doc """
  Creates a new not found post with the given URI.
  """
  def new(uri) when is_binary(uri) do
    %__MODULE__{uri: uri, not_found: true}
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
