defmodule Lexicon.App.Bsky.Labeler.LabelerPoliciesTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Labeler.LabelerPolicies

  describe "changeset/2" do
    test "validates required fields" do
      changeset = LabelerPolicies.changeset(%LabelerPolicies{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).label_values
    end

    test "accepts valid label values" do
      valid_attrs = %{
        label_values: ["nsfw", "spam", "hate"]
      }

      changeset = LabelerPolicies.changeset(%LabelerPolicies{}, valid_attrs)
      assert changeset.valid?
    end

    test "accepts optional label value definitions" do
      valid_attrs = %{
        label_values: ["nsfw", "spam", "hate"],
        label_value_definitions: [
          %{
            identifier: "nsfw",
            name: "Adult Content",
            severity: 1
          },
          %{
            identifier: "spam",
            name: "Spam",
            severity: 2
          }
        ]
      }

      changeset = LabelerPolicies.changeset(%LabelerPolicies{}, valid_attrs)
      assert changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        label_values: ["nsfw", "spam", "hate"]
      }

      assert {:ok, policies} = LabelerPolicies.validate(valid_map)
      assert policies.label_values == ["nsfw", "spam", "hate"]
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = LabelerPolicies.validate(%{})
      refute changeset.valid?
    end
  end

  # Helper functions
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
