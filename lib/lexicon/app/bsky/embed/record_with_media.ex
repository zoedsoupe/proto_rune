defmodule Lexicon.App.Bsky.Embed.RecordWithMedia do
  @moduledoc """
  A representation of a record embedded in a Bluesky record (eg, a post),
  alongside other compatible embeds. For example, a quote post and image,
  or a quote post and external URL card.

  NSID: app.bsky.embed.recordWithMedia
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Embed.External
  alias Lexicon.App.Bsky.Embed.Images
  alias Lexicon.App.Bsky.Embed.Record
  alias Lexicon.App.Bsky.Embed.Video

  @type t :: %__MODULE__{
          record: Record.t(),
          media: Images.t() | Video.t() | External.t()
        }

  @primary_key false
  embedded_schema do
    embeds_one :record, Record
    # Can be Images, Video, or External
    field :media, :map
  end

  @doc """
  Creates a changeset for validating a record with media embed.
  """
  def changeset(record_with_media, attrs) do
    record_with_media
    |> cast(attrs, [:media])
    |> cast_embed(:record, required: true)
    |> validate_required([:media])
    |> validate_media()
  end

  defp validate_media(changeset) do
    if media = get_field(changeset, :media) do
      cond do
        not is_map(media) ->
          add_error(changeset, :media, "must be a map")

        # Check if it's a valid images embed
        Map.has_key?(media, :images) ->
          validate_images_embed(changeset, media)

        # Check if it's a valid video embed
        Map.has_key?(media, :video) ->
          validate_video_embed(changeset, media)

        # Check if it's a valid external embed
        Map.has_key?(media, :external) ->
          validate_external_embed(changeset, media)

        true ->
          add_error(changeset, :media, "must be a valid Images, Video, or External embed")
      end
    else
      changeset
    end
  end

  defp validate_images_embed(changeset, media) do
    images = Map.get(media, :images)

    if is_list(images) and length(images) <= 4 do
      changeset
    else
      add_error(changeset, :media, "images must be a list with a maximum of 4 items")
    end
  end

  defp validate_video_embed(changeset, media) do
    if is_map(Map.get(media, :video)) do
      changeset
    else
      add_error(changeset, :media, "video must be a valid blob reference")
    end
  end

  defp validate_external_embed(changeset, media) do
    external = Map.get(media, :external)

    if is_map(external) and Map.has_key?(external, :uri) do
      changeset
    else
      add_error(changeset, :media, "external must be a valid external reference with a URI")
    end
  end

  @doc """
  Creates a new record with media embed with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new record with media embed, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, record_with_media} -> record_with_media
      {:error, changeset} -> raise "Invalid record with media embed: #{inspect(changeset.errors)}"
    end
  end
end
