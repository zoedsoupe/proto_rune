defmodule Lexicon.Chat.Bsky.Moderation.MetadataTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.Chat.Bsky.Moderation.Metadata

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Metadata.changeset(%Metadata{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).messages_sent
      assert "can't be blank" in errors_on(changeset).messages_received
      assert "can't be blank" in errors_on(changeset).convos
      assert "can't be blank" in errors_on(changeset).convos_started
    end

    test "validates that counts are non-negative" do
      # Valid counts (all positive)
      changeset = Metadata.changeset(%Metadata{}, %{
        messages_sent: 10,
        messages_received: 5,
        convos: 3,
        convos_started: 1
      })
      assert changeset.valid?

      # Valid counts (all zero)
      changeset = Metadata.changeset(%Metadata{}, %{
        messages_sent: 0,
        messages_received: 0,
        convos: 0,
        convos_started: 0
      })
      assert changeset.valid?

      # Invalid count (negative)
      changeset = Metadata.changeset(%Metadata{}, %{
        messages_sent: -1,
        messages_received: 5,
        convos: 3,
        convos_started: 1
      })
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).messages_sent
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        messages_sent: 10,
        messages_received: 5,
        convos: 3,
        convos_started: 1
      }
      
      assert {:ok, metadata} = Metadata.validate(valid_map)
      assert metadata.messages_sent == 10
      assert metadata.messages_received == 5
      assert metadata.convos == 3
      assert metadata.convos_started == 1
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = Metadata.validate(%{})
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