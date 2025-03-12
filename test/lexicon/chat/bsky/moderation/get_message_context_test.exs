defmodule Lexicon.Chat.Bsky.Moderation.GetMessageContextTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.Chat.Bsky.Moderation.GetMessageContext

  describe "validate_params/1" do
    test "validates valid params" do
      params = %{
        convo_id: "convo123",
        message_id: "msg123",
        before: 10,
        after: 10
      }
      
      assert {:ok, validated} = GetMessageContext.validate_params(params)
      assert validated.convo_id == "convo123"
      assert validated.message_id == "msg123"
      assert validated.before == 10
      assert validated.after == 10
    end

    test "validates params with only required fields" do
      params = %{
        message_id: "msg123"
      }
      
      assert {:ok, validated} = GetMessageContext.validate_params(params)
      assert validated.message_id == "msg123"
    end

    test "validates non-negative before/after" do
      # Valid
      assert {:ok, _} = GetMessageContext.validate_params(%{
        message_id: "msg123",
        before: 0,
        after: 0
      })

      # Invalid before (negative)
      assert {:error, changeset} = GetMessageContext.validate_params(%{
        message_id: "msg123",
        before: -1,
        after: 0
      })
      
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).before

      # Invalid after (negative)
      assert {:error, changeset} = GetMessageContext.validate_params(%{
        message_id: "msg123",
        before: 0,
        after: -1
      })
      
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).after
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = GetMessageContext.validate_params(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).message_id
    end
  end

  describe "validate_output/1" do
    test "validates valid output" do
      output = %{
        messages: [
          %{
            id: "msg123",
            rev: "rev1",
            text: "Hello, world!",
            sender: %{did: "did:plc:1234"},
            sent_at: "2023-01-01T00:00:00Z"
          },
          %{
            id: "msg124",
            rev: "rev1",
            sender: %{did: "did:plc:1234"},
            sent_at: "2023-01-01T00:01:00Z"
          }
        ]
      }
      
      assert {:ok, validated} = GetMessageContext.validate_output(output)
      assert length(validated.messages) == 2
    end

    test "validates output with empty messages" do
      output = %{
        messages: []
      }
      
      assert {:ok, validated} = GetMessageContext.validate_output(output)
      assert validated.messages == []
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = GetMessageContext.validate_output(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).messages
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