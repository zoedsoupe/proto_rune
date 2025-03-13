defmodule Lexicon.Chat.Bsky.Convo.SendMessageTest do
  use ExUnit.Case, async: true

  alias Lexicon.Chat.Bsky.Convo.MessageInput
  alias Lexicon.Chat.Bsky.Convo.SendMessage

  describe "validate_input/1" do
    test "validates valid input" do
      input = %{
        convo_id: "convo123",
        message: %{
          text: "Hello, world!"
        }
      }

      assert {:ok, validated} = SendMessage.validate_input(input)
      assert validated.convo_id == "convo123"
      assert %MessageInput{text: "Hello, world!"} = validated.message
    end

    test "returns error for missing required fields" do
      # Missing convo_id
      assert {:error, changeset} =
               SendMessage.validate_input(%{
                 message: %{text: "Hello, world!"}
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).convo_id

      # Missing message
      assert {:error, changeset} =
               SendMessage.validate_input(%{
                 convo_id: "convo123"
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).message
    end

    test "returns error for invalid message" do
      # Invalid message (missing text)
      assert {:error, _} =
               SendMessage.validate_input(%{
                 convo_id: "convo123",
                 message: %{}
               })
    end
  end

  describe "validate_output/1" do
    test "validates valid output" do
      output = %{
        id: "msg123",
        rev: "rev1",
        text: "Hello, world!",
        sender: %{did: "did:plc:1234"},
        sent_at: "2023-01-01T00:00:00Z"
      }

      assert {:ok, _validated} = SendMessage.validate_output(output)
    end

    test "returns error for invalid output" do
      # Missing required fields
      assert {:error, _} = SendMessage.validate_output(%{})
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
