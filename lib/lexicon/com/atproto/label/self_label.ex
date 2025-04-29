defmodule Lexicon.Com.Atproto.Label.SelfLabel do
  @moduledoc """
  Metadata tag on an atproto record, published by the author within the record.

  NSID: com.atproto.label.defs#selfLabel
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          val: String.t()
        }

  @primary_key false
  embedded_schema do
    field :val, :string
  end

  @doc """
  Creates a changeset for validating a self label.
  """
  def changeset(self_label, attrs) do
    self_label
    |> cast(attrs, [:val])
    |> validate_required([:val])
    |> validate_length(:val, max: 128)
  end

  @doc """
  Creates a new self label with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new self label with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, self_label} -> self_label
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates a self label structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
