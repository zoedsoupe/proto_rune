defmodule Lexicon.App.Bsky.Actor.MutedWord do
  @moduledoc """
  A word that the account owner has muted.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor

  @type t :: %__MODULE__{
          id: String.t() | nil,
          value: String.t(),
          targets: [String.t()],
          actor_target: String.t() | nil,
          expires_at: DateTime.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :id, :string
    field :value, :string
    field :targets, {:array, :string}
    field :actor_target, :string, default: "all"
    field :expires_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a muted word.
  """
  def changeset(muted_word, attrs) do
    muted_word
    |> cast(attrs, [:id, :value, :targets, :actor_target, :expires_at])
    |> validate_required([:value, :targets])
    |> validate_length(:value, max: 10_000)
    |> validate_targets()
    |> validate_actor_target()
  end

  defp validate_targets(changeset) do
    targets = get_field(changeset, :targets)

    if targets do
      invalid_targets = Enum.filter(targets, fn target -> !Actor.valid_muted_word_target?(target) end)

      if Enum.empty?(invalid_targets) do
        changeset
      else
        add_error(changeset, :targets, "contains invalid target values")
      end
    else
      changeset
    end
  end

  defp validate_actor_target(changeset) do
    actor_target = get_field(changeset, :actor_target)

    if actor_target && !Actor.valid_muted_word_actor_target?(actor_target) do
      add_error(changeset, :actor_target, "must be a valid actor target value")
    else
      changeset
    end
  end

  @doc """
  Validates a muted word structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
