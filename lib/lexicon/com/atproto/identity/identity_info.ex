defmodule Lexicon.Com.Atproto.Identity.IdentityInfo do
  @moduledoc """
  Information about an identity (account).

  NSID: com.atproto.identity.defs#identityInfo
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          did_doc: map()
        }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :did_doc, :map
  end

  @doc """
  Creates a changeset for validating identity info.
  """
  def changeset(identity_info, attrs) do
    identity_info
    |> cast(attrs, [:did, :handle, :did_doc])
    |> validate_required([:did, :handle, :did_doc])
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
    |> validate_format(:handle, ~r/^[a-zA-Z0-9.-]+\.[a-zA-Z0-9-]+$/, message: "must be a valid handle")
    |> validate_did_doc()
  end

  defp validate_did_doc(changeset) do
    case get_field(changeset, :did_doc) do
      did_doc when is_map(did_doc) ->
        changeset

      _ ->
        add_error(changeset, :did_doc, "invalid DID document")
    end
  end

  @doc """
  Creates a new identity info with the given attributes.
  """
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new identity info with the given attributes, raises on error.
  """
  def new!(attrs) do
    case new(attrs) do
      {:ok, identity_info} -> identity_info
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates an identity info structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
