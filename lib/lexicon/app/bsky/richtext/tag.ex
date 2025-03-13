defmodule Lexicon.App.Bsky.Richtext.Tag do
  @moduledoc """
  Facet feature for a hashtag.
  The text usually includes a '#' prefix, but the facet reference should not
  (except in the case of 'double hash tags').

  NSID: app.bsky.richtext.facet#tag
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          tag: String.t()
        }

  @primary_key false
  embedded_schema do
    field :tag, :string
  end

  @doc """
  Creates a changeset for validating a tag.
  """
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:tag])
    |> validate_required([:tag])
    |> validate_length(:tag, max: 640)
    |> validate_graphemes(:tag, max: 64)
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
  Creates a new tag with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new tag, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, tag} -> tag
      {:error, changeset} -> raise "Invalid tag: #{inspect(changeset.errors)}"
    end
  end
end
