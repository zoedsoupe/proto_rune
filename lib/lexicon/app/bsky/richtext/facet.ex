defmodule Lexicon.App.Bsky.Richtext.Facet do
  @moduledoc """
  Annotation of a sub-string within rich text.

  NSID: app.bsky.richtext.facet
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Richtext.ByteSlice
  alias Lexicon.App.Bsky.Richtext.Link
  alias Lexicon.App.Bsky.Richtext.Mention
  alias Lexicon.App.Bsky.Richtext.Tag

  @type feature :: Mention.t() | Link.t() | Tag.t()

  @type t :: %__MODULE__{
          index: ByteSlice.t(),
          features: list(feature())
        }

  @primary_key false
  embedded_schema do
    embeds_one :index, ByteSlice
    field :features, {:array, :map}
  end

  @doc """
  Creates a changeset for validating a facet.
  """
  def changeset(facet, attrs) do
    facet
    |> cast(attrs, [:features])
    |> cast_embed(:index, required: true)
    |> validate_required([:features])
    |> validate_features()
  end

  defp validate_features(changeset) do
    features = get_field(changeset, :features)

    if is_list(features) && Enum.all?(features, &validate_feature/1) do
      changeset
    else
      add_error(changeset, :features, "must be a list of valid features (mention, link, or tag)")
    end
  end

  defp validate_feature(%{did: _} = feature) do
    case Mention.new(feature) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp validate_feature(%{uri: _} = feature) do
    case Link.new(feature) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp validate_feature(%{tag: _} = feature) do
    case Tag.new(feature) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp validate_feature(_), do: false

  @doc """
  Creates a new facet with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new facet, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, facet} -> facet
      {:error, changeset} -> raise "Invalid facet: #{inspect(changeset.errors)}"
    end
  end
end
