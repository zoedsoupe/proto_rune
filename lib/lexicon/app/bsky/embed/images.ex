defmodule Lexicon.App.Bsky.Embed.Images do
  @moduledoc """
  A set of images embedded in a Bluesky record (eg, a post).

  NSID: app.bsky.embed.images
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Embed.Image

  @type t :: %__MODULE__{
          images: list(Image.t())
        }

  @primary_key false
  embedded_schema do
    embeds_many :images, Image
  end

  @doc """
  Creates a changeset for validating a set of images.
  """
  def changeset(images, attrs) do
    images
    |> cast(attrs, [])
    |> cast_embed(:images, required: true)
    |> validate_length(:images, max: 4, message: "maximum of 4 images allowed")
  end

  @doc """
  Creates a new set of images with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new set of images, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, images} -> images
      {:error, changeset} -> raise "Invalid images: #{inspect(changeset.errors)}"
    end
  end
end
