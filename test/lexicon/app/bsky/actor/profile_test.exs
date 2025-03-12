defmodule Lexicon.App.Bsky.Actor.ProfileTest do
  use ExUnit.Case, async: true
  
  alias Lexicon.App.Bsky.Actor.Profile

  describe "changeset/2" do
    test "validates display_name length" do
      # Valid display name
      valid_name = String.duplicate("x", 640)
      changeset = Profile.changeset(%Profile{}, %{display_name: valid_name})
      assert changeset.valid?

      # Invalid display name (too long)
      long_name = String.duplicate("x", 641)
      changeset = Profile.changeset(%Profile{}, %{display_name: long_name})
      refute changeset.valid?
      assert "should be at most 640 character(s)" in errors_on(changeset).display_name
    end

    test "validates description length" do
      # Valid description
      valid_desc = String.duplicate("x", 2560)
      changeset = Profile.changeset(%Profile{}, %{description: valid_desc})
      assert changeset.valid?

      # Invalid description (too long)
      long_desc = String.duplicate("x", 2561)
      changeset = Profile.changeset(%Profile{}, %{description: long_desc})
      refute changeset.valid?
      assert "should be at most 2560 character(s)" in errors_on(changeset).description
    end

    test "validates blobs" do
      # Valid avatar blob
      valid_avatar = %{data: <<1, 2, 3>>, mime_type: "image/jpeg"}
      changeset = Profile.changeset(%Profile{}, %{avatar: valid_avatar})
      assert changeset.valid?

      # Invalid avatar blob
      invalid_avatar = "not-a-blob"
      changeset = Profile.changeset(%Profile{}, %{avatar: invalid_avatar})
      refute changeset.valid?
      assert errors_on(changeset).avatar # Just check that there's an error, not the exact message
    end

    test "accepts all fields" do
      changeset = Profile.changeset(%Profile{}, %{
        display_name: "Test User",
        description: "This is a test profile",
        avatar: %{data: <<1, 2, 3>>, mime_type: "image/jpeg"},
        banner: %{data: <<4, 5, 6>>, mime_type: "image/png"},
        labels: %{type: "com.atproto.label.defs#selfLabels", values: []},
        pinned_post: %{uri: "at://did:plc:1234/app.bsky.feed.post/1", cid: "cid"},
        created_at: DateTime.utc_now()
      })
      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a new profile with default created_at" do
      {:ok, profile} = Profile.new(%{display_name: "Test User"})
      assert profile.display_name == "Test User"
      assert %DateTime{} = profile.created_at
    end

    test "creates a new profile with custom created_at" do
      created_at = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, profile} = Profile.new(%{display_name: "Test User", created_at: created_at})
      assert profile.display_name == "Test User"
      assert profile.created_at == created_at
    end

    test "returns error for invalid data" do
      long_name = String.duplicate("x", 641)
      assert {:error, changeset} = Profile.new(%{display_name: long_name})
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