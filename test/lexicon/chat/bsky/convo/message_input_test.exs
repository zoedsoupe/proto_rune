defmodule Lexicon.Chat.Bsky.Convo.MessageInputTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.Chat.Bsky.Convo.MessageInput

  describe "changeset/2" do
    test "validates required fields" do
      changeset = MessageInput.changeset(%MessageInput{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).text
    end

    test "validates text length" do
      # Valid text (under limit)
      changeset = MessageInput.changeset(%MessageInput{}, %{text: "Hello, world!"})
      assert changeset.valid?

      # Invalid text (over limit)
      long_text = String.duplicate("x", 10001)
      changeset = MessageInput.changeset(%MessageInput{}, %{text: long_text})
      refute changeset.valid?
      assert "should be at most 10000 character(s)" in errors_on(changeset).text
    end

    test "accepts optional fields" do
      facets = [%{index: %{byteStart: 0, byteEnd: 5}, features: [%{type: "app.bsky.richtext.facet#link", uri: "https://example.com"}]}]
      embed = %{type: "app.bsky.embed.record", record: %{uri: "at://did:example/repo/collection/record"}}
      
      changeset = MessageInput.changeset(%MessageInput{}, %{
        text: "Hello, world!",
        facets: facets,
        embed: embed
      })
      
      assert changeset.valid?
      assert get_change(changeset, :facets) == facets
      assert get_change(changeset, :embed) == embed
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      assert {:ok, message_input} = MessageInput.validate(%{
        text: "Hello, world!"
      })
      
      assert message_input.text == "Hello, world!"
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = MessageInput.validate(%{})
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

  defp get_change(changeset, field) do
    Ecto.Changeset.get_change(changeset, field)
  end
end