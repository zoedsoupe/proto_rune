defmodule Lexicon.Com.Atproto.Server.InviteCode do
  @moduledoc """
  Information about an invite code.

  NSID: com.atproto.server.defs#inviteCode
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.Com.Atproto.Server.InviteCodeUse

  @type t :: %__MODULE__{
          code: String.t(),
          available: integer(),
          disabled: boolean(),
          for_account: String.t(),
          created_by: String.t(),
          created_at: DateTime.t(),
          uses: [InviteCodeUse.t()]
        }

  @primary_key false
  embedded_schema do
    field :code, :string
    field :available, :integer
    field :disabled, :boolean
    field :for_account, :string
    field :created_by, :string
    field :created_at, :utc_datetime
    embeds_many :uses, InviteCodeUse
  end

  @doc """
  Creates a changeset for validating an invite code.
  """
  def changeset(invite_code, attrs) do
    invite_code
    |> cast(attrs, [:code, :available, :disabled, :for_account, :created_by, :created_at])
    |> validate_required([:code, :available, :disabled, :for_account, :created_by, :created_at])
    |> cast_embed(:uses)
  end

  @doc """
  Creates a new invite code with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new invite code with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, invite_code} -> invite_code
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates an invite code structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
