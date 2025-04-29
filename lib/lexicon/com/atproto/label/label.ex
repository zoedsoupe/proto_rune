defmodule Lexicon.Com.Atproto.Label.Label do
  @moduledoc """
  Metadata tag on an atproto resource (eg, repo or record).

  NSID: com.atproto.label.defs#label
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          ver: integer() | nil,
          src: String.t(),
          uri: String.t(),
          cid: String.t() | nil,
          val: String.t(),
          neg: boolean() | nil,
          cts: DateTime.t(),
          exp: DateTime.t() | nil,
          sig: binary() | nil
        }

  @primary_key false
  embedded_schema do
    field :ver, :integer
    field :src, :string
    field :uri, :string
    field :cid, :string
    field :val, :string
    field :neg, :boolean, default: false
    field :cts, :utc_datetime
    field :exp, :utc_datetime
    field :sig, :binary
  end

  @doc """
  Creates a changeset for validating a label.
  """
  def changeset(label, attrs) do
    label
    |> cast(attrs, [:ver, :src, :uri, :cid, :val, :neg, :cts, :exp, :sig])
    |> validate_required([:src, :uri, :val, :cts])
    |> validate_length(:val, max: 128)
    |> validate_format(:src, ~r/^did:/, message: "must be a DID")
    |> validate_format(:uri, ~r/^at:/, message: "must be an AT URI")
  end

  @doc """
  Creates a new label with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new label with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, label} -> label
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates a label structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
