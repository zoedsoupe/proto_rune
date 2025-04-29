defmodule Lexicon.App.Bsky.Unspecced.SkeletonSearchPostTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchPost

  describe "changeset/2" do
    test "validates required fields" do
      changeset = SkeletonSearchPost.changeset(%SkeletonSearchPost{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).uri
    end

    test "validates uri format" do
      # Valid AT URI
      valid_attrs = %{uri: "at://did:plc:1234/app.bsky.feed.post/1234"}
      changeset = SkeletonSearchPost.changeset(%SkeletonSearchPost{}, valid_attrs)
      assert changeset.valid?

      # Invalid format
      invalid_attrs = %{uri: "invalid:uri"}
      changeset = SkeletonSearchPost.changeset(%SkeletonSearchPost{}, invalid_attrs)
      refute changeset.valid?
      assert "must be an AT-URI" in errors_on(changeset).uri
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{uri: "at://did:plc:1234/app.bsky.feed.post/1234"}

      assert {:ok, skeleton} = SkeletonSearchPost.validate(valid_map)
      assert skeleton.uri == "at://did:plc:1234/app.bsky.feed.post/1234"
    end

    test "returns error with invalid data" do
      invalid_map = %{uri: "invalid:uri"}
      assert {:error, changeset} = SkeletonSearchPost.validate(invalid_map)
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
