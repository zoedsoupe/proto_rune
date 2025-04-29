defmodule Lexicon.App.Bsky.Labeler.LabelerPolicies do
  @moduledoc """
  Policies for a labeler service.

  Part of app.bsky.labeler lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          label_values: [String.t()],
          label_value_definitions: [map()] | nil
        }

  @primary_key false
  embedded_schema do
    # Array of com.atproto.label.defs#labelValue
    field :label_values, {:array, :string}
    # Array of com.atproto.label.defs#labelValueDefinition
    field :label_value_definitions, {:array, :map}
  end

  @doc """
  Creates a changeset for validating labeler policies.
  """
  def changeset(policies, attrs) do
    policies
    |> cast(attrs, [:label_values, :label_value_definitions])
    |> validate_required([:label_values])
  end

  @doc """
  Validates a labeler policies structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
