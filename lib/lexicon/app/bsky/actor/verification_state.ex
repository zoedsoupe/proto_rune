defmodule Lexicon.App.Bsky.Actor.VerificationState do
  @moduledoc """
  Represents the verification information about the user this object is attached to.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          verifications: [map()],
          verified_status: String.t(),
          trusted_verifier_status: String.t()
        }

  @primary_key false
  embedded_schema do
    # Array of #verificationView
    field :verifications, {:array, :map}
    # "valid", "invalid", or "none"
    field :verified_status, :string
    # "valid", "invalid", or "none"
    field :trusted_verifier_status, :string
  end

  @doc """
  Creates a changeset for validating verification state information.
  """
  def changeset(verification_state, attrs) do
    verification_state
    |> cast(attrs, [:verifications, :verified_status, :trusted_verifier_status])
    |> validate_required([:verifications, :verified_status, :trusted_verifier_status])
    |> validate_verified_status()
    |> validate_trusted_verifier_status()
  end

  defp validate_verified_status(changeset) do
    value = get_field(changeset, :verified_status)

    if value in ["valid", "invalid", "none"] do
      changeset
    else
      add_error(changeset, :verified_status, "must be one of: valid, invalid, none")
    end
  end

  defp validate_trusted_verifier_status(changeset) do
    value = get_field(changeset, :trusted_verifier_status)

    if value in ["valid", "invalid", "none"] do
      changeset
    else
      add_error(changeset, :trusted_verifier_status, "must be one of: valid, invalid, none")
    end
  end

  @doc """
  Validates verification state information structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
