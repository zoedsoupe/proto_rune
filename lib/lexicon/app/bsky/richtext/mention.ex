defmodule Lexicon.App.Bsky.Richtext.Mention do
  @moduledoc """
  Facet feature for mention of another account.
  The text is usually a handle, including a '@' prefix,
  but the facet reference is a DID.

  NSID: app.bsky.richtext.facet#mention
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t()
        }

  @primary_key false
  embedded_schema do
    field :did, :string
  end

  @doc """
  Creates a changeset for validating a mention.
  """
  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [:did])
    |> validate_required([:did])
    |> validate_format(:did, ~r/^did:/, message: "must be a valid DID format")
  end

  @doc """
  Creates a new mention with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new mention, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, mention} -> mention
      {:error, changeset} -> raise "Invalid mention: #{inspect(changeset.errors)}"
    end
  end
end
