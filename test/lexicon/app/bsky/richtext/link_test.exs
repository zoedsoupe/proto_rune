defmodule Lexicon.App.Bsky.Richtext.LinkTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Richtext.Link

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Link.changeset(%Link{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).uri
    end

    test "validates URI format" do
      # Valid HTTP URIs
      for uri <- ["https://example.com", "http://example.org/path?query=1"] do
        changeset = Link.changeset(%Link{}, %{uri: uri})
        assert changeset.valid?
      end

      # Invalid URIs
      for uri <- ["example.com", "ftp://example.com", "not-a-uri"] do
        changeset = Link.changeset(%Link{}, %{uri: uri})
        refute changeset.valid?
        assert "must be a valid HTTP(S) URI" in errors_on(changeset).uri
      end
    end
  end

  describe "new/1" do
    test "creates a valid link" do
      uri = "https://example.com"
      assert {:ok, link} = Link.new(%{uri: uri})
      assert link.uri == uri
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Link.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid link" do
      uri = "https://example.com"
      assert %Link{} = link = Link.new!(%{uri: uri})
      assert link.uri == uri
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid link/, fn ->
        Link.new!(%{})
      end
    end
  end
end
