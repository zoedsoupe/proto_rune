defmodule Lexicon.Chat.Bsky.Convo.MessageViewTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.Chat.Bsky.Convo.MessageView
  alias Lexicon.Chat.Bsky.Convo.MessageViewSender

  describe "changeset/2" do
    test "validates required fields" do
      changeset = MessageView.changeset(%MessageView{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).id
      assert "can't be blank" in errors_on(changeset).rev
      assert "can't be blank" in errors_on(changeset).text
      assert "can't be blank" in errors_on(changeset).sent_at
    end

    test "validates text length" do
      # Valid message with all required fields
      valid_attrs = %{
        id: "msg123",
        rev: "rev1",
        text: "Hello, world!",
        sender: %{did: "did:plc:1234"},
        sent_at: DateTime.utc_now()
      }
      
      changeset = MessageView.changeset(%MessageView{}, valid_attrs)
      assert changeset.valid?

      # Invalid text (over limit)
      long_text = String.duplicate("x", 10001)
      invalid_attrs = Map.put(valid_attrs, :text, long_text)
      
      changeset = MessageView.changeset(%MessageView{}, invalid_attrs)
      refute changeset.valid?
      assert "should be at most 10000 character(s)" in errors_on(changeset).text
    end

    test "validates nested sender" do
      # Valid message with valid sender
      valid_attrs = %{
        id: "msg123",
        rev: "rev1",
        text: "Hello, world!",
        sender: %{did: "did:plc:1234"},
        sent_at: DateTime.utc_now()
      }
      
      changeset = MessageView.changeset(%MessageView{}, valid_attrs)
      assert changeset.valid?

      # Missing sender entirely
      invalid_attrs = Map.delete(valid_attrs, :sender)
      
      changeset = MessageView.changeset(%MessageView{}, invalid_attrs)
      refute changeset.valid?
      assert errors_on(changeset).sender
    end

    test "accepts optional fields" do
      facets = [%{index: %{byteStart: 0, byteEnd: 5}, features: [%{type: "app.bsky.richtext.facet#link", uri: "https://example.com"}]}]
      embed = %{type: "app.bsky.embed.record#view", record: %{uri: "at://did:example/repo/collection/record"}}
      
      valid_attrs = %{
        id: "msg123",
        rev: "rev1",
        text: "Hello, world!",
        facets: facets,
        embed: embed,
        sender: %{did: "did:plc:1234"},
        sent_at: DateTime.utc_now()
      }
      
      changeset = MessageView.changeset(%MessageView{}, valid_attrs)
      assert changeset.valid?
      assert get_change(changeset, :facets) == facets
      assert get_change(changeset, :embed) == embed
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        id: "msg123",
        rev: "rev1",
        text: "Hello, world!",
        sender: %{did: "did:plc:1234"},
        sent_at: "2023-01-01T00:00:00Z"
      }
      
      assert {:ok, message_view} = MessageView.validate(valid_map)
      assert message_view.id == "msg123"
      assert message_view.text == "Hello, world!"
      assert %MessageViewSender{did: "did:plc:1234"} = message_view.sender
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = MessageView.validate(%{})
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