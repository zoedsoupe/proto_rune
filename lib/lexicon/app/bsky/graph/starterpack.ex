defmodule Lexicon.App.Bsky.Graph.Starterpack do
  @moduledoc """
  Record defining a starter pack of actors and feeds for new users.

  NSID: app.bsky.graph.starterpack
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Richtext.Facet

  @type feed_item :: %{
          uri: String.t()
        }

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          description_facets: list(Facet.t()) | nil,
          list: String.t(),
          feeds: list(feed_item()) | nil,
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :description, :string
    field :description_facets, {:array, :map}
    field :list, :string
    field :feeds, {:array, :map}
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a starter pack.
  """
  def changeset(starterpack, attrs) do
    starterpack
    |> cast(attrs, [
      :name,
      :description,
      :description_facets,
      :list,
      :feeds,
      :created_at
    ])
    |> validate_required([:name, :list, :created_at])
    |> validate_length(:name, min: 1, max: 500)
    |> validate_graphemes(:name, max: 50)
    |> validate_description()
    |> validate_format(:list, ~r/^at:\/\//, message: "list must be an AT-URI")
    |> validate_feeds()
  end

  defp validate_description(changeset) do
    if _desc = get_field(changeset, :description) do
      changeset
      |> validate_length(:description, max: 3000)
      |> validate_graphemes(:description, max: 300)
    else
      changeset
    end
  end

  defp validate_feeds(changeset) do
    case get_field(changeset, :feeds) do
      nil ->
        changeset

      feeds when not is_list(feeds) ->
        add_error(changeset, :feeds, "must be a list")

      feeds when length(feeds) > 3 ->
        add_error(changeset, :feeds, "cannot have more than 3 feeds")

      feeds ->
        validate_feed_uris(changeset, feeds)
    end
  end

  defp validate_feed_uris(changeset, feeds) do
    feeds_valid = Enum.all?(feeds, &valid_feed_item?/1)

    if feeds_valid do
      changeset
    else
      add_error(changeset, :feeds, "feed items must have a valid AT-URI")
    end
  end

  defp valid_feed_item?(%{uri: uri}) when is_binary(uri), do: String.match?(uri, ~r/^at:\/\//)
  defp valid_feed_item?(_), do: false

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
  Creates a new starter pack with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new starter pack, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, starterpack} -> starterpack
      {:error, changeset} -> raise "Invalid starter pack: #{inspect(changeset.errors)}"
    end
  end
end
