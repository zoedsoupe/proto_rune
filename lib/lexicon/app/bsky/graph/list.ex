defmodule Lexicon.App.Bsky.Graph.List do
  @moduledoc """
  Record representing a list of accounts (actors). 
  Scope includes both moderation-oriented lists and curation-oriented lists.

  NSID: app.bsky.graph.list
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Graph.ListPurpose
  alias Lexicon.App.Bsky.Richtext.Facet

  @type t :: %__MODULE__{
          purpose: ListPurpose.t(),
          name: String.t(),
          description: String.t() | nil,
          description_facets: list(Facet.t()) | nil,
          avatar: map() | nil,
          labels: map() | nil,
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :purpose, :string
    field :name, :string
    field :description, :string
    field :description_facets, {:array, :map}
    field :avatar, :map
    field :labels, :map
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a list.
  """
  def changeset(list, attrs) do
    list
    |> cast(attrs, [
      :purpose,
      :name,
      :description,
      :description_facets,
      :avatar,
      :labels,
      :created_at
    ])
    |> validate_required([:purpose, :name, :created_at])
    |> validate_length(:name, min: 1, max: 64)
    |> validate_list_purpose()
    |> validate_description()
  end

  defp validate_list_purpose(changeset) do
    if purpose = get_field(changeset, :purpose) do
      if purpose in ["app.bsky.graph.defs#modlist", "app.bsky.graph.defs#curatelist", "app.bsky.graph.defs#referencelist"] do
        changeset
      else
        add_error(changeset, :purpose, "invalid purpose")
      end
    else
      changeset
    end
  end

  defp validate_description(changeset) do
    if _description = get_field(changeset, :description) do
      changeset
      |> validate_length(:description, max: 3000)
      |> validate_graphemes(:description, max: 300)
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
  Creates a new list with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new list, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, list} -> list
      {:error, changeset} -> raise "Invalid list: #{inspect(changeset.errors)}"
    end
  end
end
