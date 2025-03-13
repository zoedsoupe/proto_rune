defmodule Lexicon.App.Bsky.Actor.GetProfileTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Actor.GetProfile

  describe "validate_params/1" do
    test "validates valid parameters" do
      # Valid DID
      assert {:ok, params} = GetProfile.validate_params(%{actor: "did:plc:1234"})
      assert params.actor == "did:plc:1234"

      # Valid handle
      assert {:ok, params} = GetProfile.validate_params(%{actor: "@user.bsky.social"})
      assert params.actor == "@user.bsky.social"
    end

    test "validates required parameters" do
      assert {:error, changeset} = GetProfile.validate_params(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).actor
    end

    test "validates format of actor" do
      # Invalid format (not a handle or DID)
      assert {:error, changeset} = GetProfile.validate_params(%{actor: "invalid-actor"})
      refute changeset.valid?
      assert "must be a handle or DID" in errors_on(changeset).actor
    end
  end

  describe "validate_output/1" do
    test "validates profile view detailed" do
      # This is a minimal test since the full validation is tested in ProfileViewDetailed tests
      valid_output = %{
        did: "did:plc:1234",
        handle: "user.bsky.social"
      }

      assert {:ok, _} = GetProfile.validate_output(valid_output)
    end

    test "returns error for invalid output" do
      # Missing required fields
      assert {:error, _} = GetProfile.validate_output(%{})
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
