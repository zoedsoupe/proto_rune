defmodule Lexicon.App.Bsky.Actor.VerificationView do
  @moduledoc """
  An individual verification for an associated subject.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          issuer: String.t(),
          uri: String.t(),
          is_valid: boolean(),
          created_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :issuer, :string
    field :uri, :string
    field :is_valid, :boolean
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating verification view information.
  """
  def changeset(verification_view, attrs) do
    verification_view
    |> cast(attrs, [:issuer, :uri, :is_valid, :created_at])
    |> validate_required([:issuer, :uri, :is_valid, :created_at])
    |> validate_format(:issuer, ~r/^did:/, message: "must be a DID")
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT URI")
  end

  @doc """
  Validates verification view information structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
