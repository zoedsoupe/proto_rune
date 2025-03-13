defmodule Lexicon.App.Bsky.Embed.Video do
  @moduledoc """
  A video embedded in a Bluesky record (eg, a post).

  NSID: app.bsky.embed.video
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Embed.AspectRatio
  alias Lexicon.App.Bsky.Embed.VideoCaption

  @type t :: %__MODULE__{
          # blob
          video: map(),
          captions: list(VideoCaption.t()) | nil,
          alt: String.t() | nil,
          aspect_ratio: AspectRatio.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :video, :map
    embeds_many :captions, VideoCaption
    field :alt, :string
    embeds_one :aspect_ratio, AspectRatio
  end

  @doc """
  Creates a changeset for validating a video embed.
  """
  def changeset(video, attrs) do
    video
    |> cast(attrs, [:video, :alt])
    |> cast_embed(:captions)
    |> cast_embed(:aspect_ratio)
    |> validate_required([:video])
    |> validate_captions()
    |> validate_alt()
  end

  defp validate_captions(changeset) do
    if captions = get_field(changeset, :captions) do
      if length(captions) > 20 do
        add_error(changeset, :captions, "maximum of 20 captions allowed")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_alt(changeset) do
    if _alt = get_field(changeset, :alt) do
      changeset
      |> validate_length(:alt, max: 10_000)
      |> validate_graphemes(:alt, max: 1000)
    else
      changeset
    end
  end

  # Helper function to validate graphemes count
  defp validate_graphemes(changeset, field, opts) do
    value = get_field(changeset, field)

    if value && is_binary(value) do
      graphemes_count = value |> String.graphemes() |> length()
      max = Keyword.get(opts, :max)

      if max && graphemes_count > max do
        add_error(changeset, field, "should have at most %{count} graphemes", count: max)
      else
        changeset
      end
    else
      changeset
    end
  end

  @doc """
  Creates a new video embed with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new video embed, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, video} -> video
      {:error, changeset} -> raise "Invalid video embed: #{inspect(changeset.errors)}"
    end
  end
end
