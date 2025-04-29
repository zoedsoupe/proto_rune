defmodule Lexicon.Com.Atproto.Server.InviteCodeUse do
  @moduledoc """
  Record of an invite code being used.

  NSID: com.atproto.server.defs#inviteCodeUse
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          used_by: String.t(),
          used_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :used_by, :string
    field :used_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating an invite code use.
  """
  def changeset(invite_code_use, attrs) do
    invite_code_use
    |> cast(attrs, [:used_by, :used_at])
    |> validate_required([:used_by, :used_at])
    |> validate_format(:used_by, ~r/^did:/, message: "must be a DID")
  end

  @doc """
  Creates a new invite code use with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new invite code use with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, invite_code_use} -> invite_code_use
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates an invite code use structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
