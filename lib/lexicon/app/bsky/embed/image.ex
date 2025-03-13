defmodule Lexicon.App.Bsky.Embed.Image do
  @moduledoc """
  Represents an image to be embedded in a Bluesky record.

  NSID: app.bsky.embed.images#image
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Embed.AspectRatio

  @type t :: %__MODULE__{
          # blob
          image: map(),
          alt: String.t(),
          aspect_ratio: AspectRatio.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :image, :map
    field :alt, :string
    embeds_one :aspect_ratio, AspectRatio
  end

  @doc """
  Creates a changeset for validating an image.
  """
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:image, :alt])
    |> cast_embed(:aspect_ratio)
    |> validate_required([:image, :alt])
  end

  @doc """
  Creates a new image with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new image, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, image} -> image
      {:error, changeset} -> raise "Invalid image: #{inspect(changeset.errors)}"
    end
  end
end
