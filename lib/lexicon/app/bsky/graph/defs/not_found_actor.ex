defmodule Lexicon.App.Bsky.Graph.Defs.NotFoundActor do
  @moduledoc """
  Indicates that a handle or DID could not be resolved.

  Part of app.bsky.graph.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          actor: String.t(),
          not_found: boolean()
        }

  @primary_key false
  embedded_schema do
    field :actor, :string
    field :not_found, :boolean, default: true
  end

  @doc """
  Creates a changeset for validating a not found actor.
  """
  def changeset(not_found_actor, attrs) do
    not_found_actor
    |> cast(attrs, [:actor, :not_found])
    |> validate_required([:actor, :not_found])
    |> validate_format(:actor, ~r/^(did:|@)/, message: "must be an AT identifier")
    |> validate_inclusion(:not_found, [true], message: "must be true")
  end

  @doc """
  Validates a not found actor structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
