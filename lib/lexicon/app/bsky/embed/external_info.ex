defmodule Lexicon.App.Bsky.Embed.ExternalInfo do
  @moduledoc """
  Information about externally linked content for embedding.

  NSID: app.bsky.embed.external#external
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          title: String.t(),
          description: String.t(),
          # blob
          thumb: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :title, :string
    field :description, :string
    field :thumb, :map
  end

  @doc """
  Creates a changeset for validating external info.
  """
  def changeset(external_info, attrs) do
    external_info
    |> cast(attrs, [:uri, :title, :description, :thumb])
    |> validate_required([:uri, :title, :description])
    |> validate_format(:uri, ~r/^https?:\/\//, message: "must be a valid URI")
  end

  @doc """
  Creates new external info with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates new external info, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, external_info} -> external_info
      {:error, changeset} -> raise "Invalid external info: #{inspect(changeset.errors)}"
    end
  end
end
