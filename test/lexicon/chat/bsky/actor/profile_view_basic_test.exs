defmodule Lexicon.Chat.Bsky.Actor.ProfileViewBasicTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.Chat.Bsky.Actor.ProfileViewBasic

  describe "changeset/2" do
    test "validates required fields" do
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).did
      assert "can't be blank" in errors_on(changeset).handle
    end

    test "validates did format" do
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "not-a-did",
        handle: "valid-handle"
      })
      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).did

      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "did:plc:1234",
        handle: "valid-handle"
      })
      assert changeset.valid?
    end

    test "validates display_name length" do
      long_name = String.duplicate("x", 65)
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "did:plc:1234",
        handle: "valid-handle",
        display_name: long_name
      })
      refute changeset.valid?
      assert "should be at most 64 character(s)" in errors_on(changeset).display_name

      valid_name = String.duplicate("x", 64)
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "did:plc:1234",
        handle: "valid-handle",
        display_name: valid_name
      })
      assert changeset.valid?
    end

    test "accepts optional fields" do
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "did:plc:1234",
        handle: "valid-handle",
        display_name: "Test User",
        avatar: "https://example.com/avatar.jpg",
        chat_disabled: true
      })
      assert changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      assert {:ok, profile} = ProfileViewBasic.validate(%{
        did: "did:plc:1234",
        handle: "valid-handle",
        display_name: "Test User",
        avatar: "https://example.com/avatar.jpg"
      })
      assert profile.did == "did:plc:1234"
      assert profile.handle == "valid-handle"
      assert profile.display_name == "Test User"
      assert profile.avatar == "https://example.com/avatar.jpg"
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = ProfileViewBasic.validate(%{
        handle: "valid-handle"
      })
      refute changeset.valid?
    end
  end

  # Helper function to extract error messages
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end