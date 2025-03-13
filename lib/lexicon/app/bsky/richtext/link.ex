defmodule Lexicon.App.Bsky.Richtext.Link do
  @moduledoc """
  Facet feature for a URL.
  The text URL may have been simplified or truncated,
  but the facet reference should be a complete URL.

  NSID: app.bsky.richtext.facet#link
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
  end

  @doc """
  Creates a changeset for validating a link.
  """
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:uri])
    |> validate_required([:uri])
    |> validate_format(:uri, ~r/^https?:\/\//, message: "must be a valid HTTP(S) URI")
  end

  @doc """
  Creates a new link with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new link, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, link} -> link
      {:error, changeset} -> raise "Invalid link: #{inspect(changeset.errors)}"
    end
  end
end
