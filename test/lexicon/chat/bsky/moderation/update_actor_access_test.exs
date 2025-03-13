defmodule Lexicon.Chat.Bsky.Moderation.UpdateActorAccessTest do
  use ExUnit.Case, async: true

  alias Lexicon.Chat.Bsky.Moderation.UpdateActorAccess

  describe "validate_input/1" do
    test "validates valid input" do
      input = %{
        actor: "did:plc:1234",
        allow_access: true,
        ref: "abc123"
      }

      assert {:ok, validated} = UpdateActorAccess.validate_input(input)
      assert validated.actor == "did:plc:1234"
      assert validated.allow_access == true
      assert validated.ref == "abc123"
    end

    test "validates input with only required fields" do
      input = %{
        actor: "did:plc:1234",
        allow_access: false
      }

      assert {:ok, validated} = UpdateActorAccess.validate_input(input)
      assert validated.actor == "did:plc:1234"
      assert validated.allow_access == false
      refute Map.has_key?(validated, :ref)
    end

    test "validates DID format" do
      # Invalid format (not starting with did:)
      assert {:error, changeset} =
               UpdateActorAccess.validate_input(%{
                 actor: "not-a-did",
                 allow_access: true
               })

      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).actor
    end

    test "returns error for missing required fields" do
      # Missing actor
      assert {:error, changeset} =
               UpdateActorAccess.validate_input(%{
                 allow_access: true
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).actor

      # Missing allow_access
      assert {:error, changeset} =
               UpdateActorAccess.validate_input(%{
                 actor: "did:plc:1234"
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).allow_access
    end
  end

  describe "validate_output/1" do
    test "validates nil output" do
      assert {:ok, nil} = UpdateActorAccess.validate_output(nil)
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
