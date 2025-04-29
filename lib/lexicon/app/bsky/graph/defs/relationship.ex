defmodule Lexicon.App.Bsky.Graph.Defs.Relationship do
  @moduledoc """
  Lists the bi-directional graph relationships between one actor (not indicated in the object)
  and the target actors (the DID included in the object).

  Part of app.bsky.graph.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t(),
          following: String.t() | nil,
          followed_by: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :following, :string
    field :followed_by, :string
  end

  @doc """
  Creates a changeset for validating a relationship.
  """
  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:did, :following, :followed_by])
    |> validate_required([:did])
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
    |> validate_format(:following, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_format(:followed_by, ~r/^at:\/\//, message: "must be an AT-URI")
  end

  @doc """
  Validates a relationship structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
