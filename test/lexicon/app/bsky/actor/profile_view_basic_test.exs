defmodule Lexicon.App.Bsky.Actor.ProfileViewBasicTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.App.Bsky.Actor.ProfileViewBasic

  describe "changeset/2" do
    test "validates required fields" do
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).did
      assert "can't be blank" in errors_on(changeset).handle
    end

    test "validates did format" do
      # Invalid format
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "not-a-did",
        handle: "valid-handle"
      })
      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).did

      # Valid format
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "did:plc:1234",
        handle: "valid-handle"
      })
      assert changeset.valid?
    end

    test "validates display_name length" do
      attrs = %{
        did: "did:plc:1234",
        handle: "valid-handle"
      }

      # Valid display name
      valid_name = String.duplicate("x", 640)
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, Map.put(attrs, :display_name, valid_name))
      assert changeset.valid?

      # Invalid display name (too long)
      long_name = String.duplicate("x", 641)
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, Map.put(attrs, :display_name, long_name))
      refute changeset.valid?
      assert "should be at most 640 character(s)" in errors_on(changeset).display_name
    end

    test "accepts optional fields" do
      changeset = ProfileViewBasic.changeset(%ProfileViewBasic{}, %{
        did: "did:plc:1234",
        handle: "valid-handle",
        display_name: "Test User",
        avatar: "https://example.com/avatar.jpg",
        created_at: DateTime.utc_now()
      })
      assert changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        did: "did:plc:1234",
        handle: "valid-handle",
        display_name: "Test User",
        avatar: "https://example.com/avatar.jpg"
      }
      
      assert {:ok, profile} = ProfileViewBasic.validate(valid_map)
      assert profile.did == "did:plc:1234"
      assert profile.handle == "valid-handle"
      assert profile.display_name == "Test User"
      assert profile.avatar == "https://example.com/avatar.jpg"
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = ProfileViewBasic.validate(%{})
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