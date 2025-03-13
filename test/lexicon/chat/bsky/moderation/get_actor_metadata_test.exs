defmodule Lexicon.Chat.Bsky.Moderation.GetActorMetadataTest do
  use ExUnit.Case, async: true

  alias Lexicon.Chat.Bsky.Moderation.GetActorMetadata

  describe "validate_params/1" do
    test "validates valid params" do
      params = %{
        actor: "did:plc:1234"
      }

      assert {:ok, validated} = GetActorMetadata.validate_params(params)
      assert validated.actor == "did:plc:1234"
    end

    test "validates DID format" do
      # Invalid format (not starting with did:)
      assert {:error, changeset} =
               GetActorMetadata.validate_params(%{
                 actor: "not-a-did"
               })

      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).actor
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = GetActorMetadata.validate_params(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).actor
    end
  end

  describe "validate_output/1" do
    test "validates valid output" do
      metadata = %{
        messages_sent: 10,
        messages_received: 5,
        convos: 3,
        convos_started: 1
      }

      output = %{
        day: metadata,
        month: metadata,
        all: metadata
      }

      assert {:ok, validated} = GetActorMetadata.validate_output(output)
      assert validated.day.messages_sent == 10
      assert validated.month.messages_sent == 10
      assert validated.all.messages_sent == 10
    end

    test "returns error for missing required fields" do
      # Missing day
      assert {:error, changeset} =
               GetActorMetadata.validate_output(%{
                 month: %{
                   messages_sent: 10,
                   messages_received: 5,
                   convos: 3,
                   convos_started: 1
                 },
                 all: %{
                   messages_sent: 10,
                   messages_received: 5,
                   convos: 3,
                   convos_started: 1
                 }
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).day
    end

    test "returns error for invalid metadata" do
      # Invalid metadata (missing fields)
      assert {:error, _} =
               GetActorMetadata.validate_output(%{
                 day: %{},
                 month: %{
                   messages_sent: 10,
                   messages_received: 5,
                   convos: 3,
                   convos_started: 1
                 },
                 all: %{
                   messages_sent: 10,
                   messages_received: 5,
                   convos: 3,
                   convos_started: 1
                 }
               })
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
