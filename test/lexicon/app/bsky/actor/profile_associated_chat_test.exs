defmodule Lexicon.App.Bsky.Actor.ProfileAssociatedChatTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Actor.ProfileAssociatedChat

  describe "changeset/2" do
    test "validates required fields" do
      changeset = ProfileAssociatedChat.changeset(%ProfileAssociatedChat{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).allow_incoming
    end

    test "validates allow_incoming enum values" do
      # Valid values
      changeset = ProfileAssociatedChat.changeset(%ProfileAssociatedChat{}, %{allow_incoming: :all})
      assert changeset.valid?

      changeset = ProfileAssociatedChat.changeset(%ProfileAssociatedChat{}, %{allow_incoming: :none})
      assert changeset.valid?

      changeset = ProfileAssociatedChat.changeset(%ProfileAssociatedChat{}, %{allow_incoming: :following})
      assert changeset.valid?

      # Invalid value
      changeset = ProfileAssociatedChat.changeset(%ProfileAssociatedChat{}, %{allow_incoming: :invalid})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).allow_incoming
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{allow_incoming: :all}

      assert {:ok, profile_chat} = ProfileAssociatedChat.validate(valid_map)
      assert profile_chat.allow_incoming == :all
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = ProfileAssociatedChat.validate(%{})
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
