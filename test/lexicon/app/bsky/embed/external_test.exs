defmodule Lexicon.App.Bsky.Embed.ExternalTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.External
  alias Lexicon.App.Bsky.Embed.ExternalInfo

  describe "changeset/2" do
    test "validates required external field" do
      changeset = External.changeset(%External{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).external
    end

    test "validates embedded external info" do
      # Valid external info
      changeset =
        External.changeset(%External{}, %{
          external: %{
            uri: "https://example.com",
            title: "Example Website",
            description: "This is an example website"
          }
        })

      assert changeset.valid?

      # Invalid external info (missing fields)
      changeset =
        External.changeset(%External{}, %{
          external: %{
            uri: "https://example.com"
          }
        })

      refute changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a valid external embed" do
      external_data = %{
        uri: "https://example.com",
        title: "Example Website",
        description: "This is an example website"
      }

      assert {:ok, external} = External.new(%{external: external_data})
      assert %ExternalInfo{} = external.external
      assert external.external.uri == "https://example.com"
      assert external.external.title == "Example Website"
      assert external.external.description == "This is an example website"
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = External.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid external embed" do
      external_data = %{
        uri: "https://example.com",
        title: "Example Website",
        description: "This is an example website"
      }

      assert %External{} = external = External.new!(%{external: external_data})
      assert %ExternalInfo{} = external.external
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid external embed/, fn ->
        External.new!(%{})
      end
    end
  end
end
