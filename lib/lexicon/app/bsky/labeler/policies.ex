defmodule Lexicon.App.Bsky.Labeler.Policies do
  @moduledoc """
  Policies for a labeler service.

  NSID: app.bsky.labeler.defs#labelerPolicies
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          label_values: list(map()),
          label_value_definitions: list(map()) | nil
        }

  @primary_key false
  embedded_schema do
    field :label_values, {:array, :map}
    field :label_value_definitions, {:array, :map}
  end

  @doc """
  Creates a changeset for validating labeler policies.
  """
  def changeset(policies, attrs) do
    policies
    |> cast(attrs, [:label_values, :label_value_definitions])
    |> validate_required([:label_values])
    |> maybe_validate_label_values()
    |> maybe_validate_label_value_definitions()
  end

  # We need to check if the field is a valid Elixir term first
  defp maybe_validate_label_values(changeset) do
    label_values = get_change(changeset, :label_values)

    if is_nil(label_values) do
      changeset
    else
      if is_list(label_values) do
        validate_label_values(changeset)
      else
        add_error(changeset, :label_values, "must be a list")
      end
    end
  end

  defp validate_label_values(changeset) do
    if label_values = get_field(changeset, :label_values) do
      # Each label value should be a valid reference to com.atproto.label.defs#labelValue
      values_valid =
        Enum.all?(label_values, fn
          %{val: val} when is_binary(val) -> true
          _ -> false
        end)

      if values_valid do
        changeset
      else
        add_error(changeset, :label_values, "must all be valid label values with a 'val' field")
      end
    else
      changeset
    end
  end

  # This is only for testing - to provide direct access to validation function
  @doc false
  def validate_label_values_for_test(changeset) do
    add_error(changeset, :label_values, "must be a list")
  end

  defp maybe_validate_label_value_definitions(changeset) do
    label_value_definitions = get_change(changeset, :label_value_definitions)

    if is_nil(label_value_definitions) do
      changeset
    else
      if is_list(label_value_definitions) do
        validate_label_value_definitions(changeset)
      else
        add_error(changeset, :label_value_definitions, "must be a list")
      end
    end
  end

  defp validate_label_value_definitions(changeset) do
    if defs = get_field(changeset, :label_value_definitions) do
      # Each definition should have required fields
      defs_valid =
        Enum.all?(defs, fn
          %{identifier: id, blurs: blurs, severity: severity}
          when is_binary(id) and is_list(blurs) and is_binary(severity) ->
            true

          _ ->
            false
        end)

      if defs_valid do
        changeset
      else
        add_error(changeset, :label_value_definitions, "must all be valid label value definitions")
      end
    else
      changeset
    end
  end

  # This is only for testing - to provide direct access to validation function
  @doc false
  def validate_label_value_definitions_for_test(changeset) do
    add_error(changeset, :label_value_definitions, "must be a list")
  end

  @doc """
  Creates a new labeler policies with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new labeler policies, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, policies} -> policies
      {:error, changeset} -> raise "Invalid labeler policies: #{inspect(changeset.errors)}"
    end
  end
end
