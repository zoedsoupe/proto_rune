defmodule Lexicon.App.Bsky.Embed.External do
  @moduledoc """
  A representation of some externally linked content (eg, a URL and 'card'),
  embedded in a Bluesky record (eg, a post).

  NSID: app.bsky.embed.external
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Embed.ExternalInfo

  @type t :: %__MODULE__{
          external: ExternalInfo.t()
        }

  @primary_key false
  embedded_schema do
    embeds_one :external, ExternalInfo
  end

  @doc """
  Creates a changeset for validating an external embed.
  """
  def changeset(external, attrs) do
    external
    |> cast(attrs, [])
    |> cast_embed(:external, required: true)
  end

  @doc """
  Creates a new external embed with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new external embed, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, external} -> external
      {:error, changeset} -> raise "Invalid external embed: #{inspect(changeset.errors)}"
    end
  end
end
