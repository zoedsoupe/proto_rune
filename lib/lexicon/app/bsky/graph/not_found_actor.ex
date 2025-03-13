defmodule Lexicon.App.Bsky.Graph.NotFoundActor do
  @moduledoc """
  Indicates that a handle or DID could not be resolved.

  NSID: app.bsky.graph.defs#notFoundActor
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
    |> validate_format(:actor, ~r/^(did:|@)/, message: "actor must be a DID or handle")
    |> validate_inclusion(:not_found, [true], message: "must be true")
  end

  @doc """
  Creates a new not found actor with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :not_found, true)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new not found actor, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, not_found_actor} -> not_found_actor
      {:error, changeset} -> raise "Invalid not found actor: #{inspect(changeset.errors)}"
    end
  end
end
