defmodule Lexicon.App.Bsky.Feed.Post do
  @moduledoc """
  Record containing a Bluesky post.

  NSID: app.bsky.feed.post
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          text: String.t(),
          # DEPRECATED
          entities: [map()] | nil,
          # app.bsky.richtext.facet
          facets: [map()] | nil,
          # replyRef
          reply: map() | nil,
          # Union of various embeds
          embed: map() | nil,
          langs: [String.t()] | nil,
          # Union
          labels: map() | nil,
          tags: [String.t()] | nil,
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :text, :string
    # DEPRECATED
    field :entities, {:array, :map}
    # Reference to app.bsky.richtext.facet
    field :facets, {:array, :map}
    # Reference to #replyRef
    field :reply, :map
    # Union of various embeds
    field :embed, :map
    field :langs, {:array, :string}
    # Union
    field :labels, :map
    field :tags, {:array, :string}
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a post.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:text, :entities, :facets, :reply, :embed, :langs, :labels, :tags, :created_at])
    |> validate_required([:text, :created_at])
    |> validate_length(:text, max: 3000)
    |> validate_length(:langs, max: 3)
    |> validate_length(:tags, max: 8)
    |> validate_tags()
  end

  defp validate_tags(changeset) do
    case get_field(changeset, :tags) do
      nil -> changeset
      tags -> validate_tag_lengths(tags, changeset)
    end
  end

  defp validate_tag_lengths(tags, changeset) do
    Enum.reduce(tags, changeset, fn tag, acc ->
      validate_tag_length(tag, acc)
    end)
  end

  defp validate_tag_length(tag, changeset) do
    if String.length(tag) > 640 do
      add_error(changeset, :tags, "tag should be at most 640 character(s)")
    else
      changeset
    end
  end

  @doc """
  Creates a new post with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new post, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, post} -> post
      {:error, changeset} -> raise "Invalid post: #{inspect(changeset.errors)}"
    end
  end
end
