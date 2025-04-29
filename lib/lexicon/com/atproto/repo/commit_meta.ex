defmodule Lexicon.Com.Atproto.Repo.CommitMeta do
  @moduledoc """
  Meta information about a commit operation.

  NSID: com.atproto.repo.defs#commitMeta
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          cid: String.t(),
          rev: String.t()
        }

  @primary_key false
  embedded_schema do
    field :cid, :string
    field :rev, :string
  end

  @doc """
  Creates a changeset for validating a commit meta structure.
  """
  def changeset(commit_meta, attrs) do
    commit_meta
    |> cast(attrs, [:cid, :rev])
    |> validate_required([:cid, :rev])
    |> validate_format(:rev, ~r/^\d+/, message: "must be a valid TID format")
  end

  @doc """
  Creates a new commit meta with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new commit meta with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, commit_meta} -> commit_meta
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates a commit meta structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
