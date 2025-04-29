defmodule Lexicon.Com.Atproto.Label.LabelValueDefinitionStrings do
  @moduledoc """
  Strings which describe the label in the UI, localized into a specific language.

  NSID: com.atproto.label.defs#labelValueDefinitionStrings
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          lang: String.t(),
          name: String.t(),
          description: String.t()
        }

  @primary_key false
  embedded_schema do
    field :lang, :string
    field :name, :string
    field :description, :string
  end

  @doc """
  Creates a changeset for validating label value definition strings.
  """
  def changeset(strings, attrs) do
    strings
    |> cast(attrs, [:lang, :name, :description])
    |> validate_required([:lang, :name, :description])
    |> validate_length(:name, max: 640)
    |> validate_length(:description, max: 100_000)
    |> validate_format(:lang, ~r/^[a-z]{2}(-[A-Z]{2})?$/, message: "must be a valid language code")
  end

  @doc """
  Creates new label value definition strings with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates new label value definition strings with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, strings} -> strings
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates label value definition strings structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
