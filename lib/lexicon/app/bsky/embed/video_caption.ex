defmodule Lexicon.App.Bsky.Embed.VideoCaption do
  @moduledoc """
  Caption for a video embedded in a Bluesky record.

  NSID: app.bsky.embed.video#caption
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          lang: String.t(),
          # blob
          file: map()
        }

  @primary_key false
  embedded_schema do
    field :lang, :string
    field :file, :map
  end

  @doc """
  Creates a changeset for validating a video caption.
  """
  def changeset(caption, attrs) do
    caption
    |> cast(attrs, [:lang, :file])
    |> validate_required([:lang, :file])
    |> validate_format(:lang, ~r/^[a-z]{2}(-[A-Z]{2})?$/, message: "must be a valid language code")
  end

  @doc """
  Creates a new video caption with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new video caption, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, caption} -> caption
      {:error, changeset} -> raise "Invalid video caption: #{inspect(changeset.errors)}"
    end
  end
end
