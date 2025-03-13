defmodule Lexicon.App.Bsky.Embed.ExternalInfoTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.ExternalInfo

  describe "changeset/2" do
    test "validates required fields" do
      changeset = ExternalInfo.changeset(%ExternalInfo{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).uri
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).description
    end

    test "validates URI format" do
      # Valid URIs
      for uri <- ["https://example.com", "http://example.org/path?query=1"] do
        changeset =
          ExternalInfo.changeset(%ExternalInfo{}, %{
            uri: uri,
            title: "Example",
            description: "Description"
          })

        assert changeset.valid?
      end

      # Invalid URIs
      for uri <- ["example.com", "ftp://example.com", "not-a-uri"] do
        changeset =
          ExternalInfo.changeset(%ExternalInfo{}, %{
            uri: uri,
            title: "Example",
            description: "Description"
          })

        refute changeset.valid?
        assert "must be a valid URI" in errors_on(changeset).uri
      end
    end

    test "accepts optional thumb field" do
      # Without thumb
      changeset =
        ExternalInfo.changeset(%ExternalInfo{}, %{
          uri: "https://example.com",
          title: "Example",
          description: "Description"
        })

      assert changeset.valid?

      # With thumb
      changeset =
        ExternalInfo.changeset(%ExternalInfo{}, %{
          uri: "https://example.com",
          title: "Example",
          description: "Description",
          thumb: %{cid: "blob123", mimeType: "image/jpeg"}
        })

      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates valid external info without thumb" do
      assert {:ok, external_info} =
               ExternalInfo.new(%{
                 uri: "https://example.com",
                 title: "Example Website",
                 description: "This is an example website"
               })

      assert external_info.uri == "https://example.com"
      assert external_info.title == "Example Website"
      assert external_info.description == "This is an example website"
      assert external_info.thumb == nil
    end

    test "creates valid external info with thumb" do
      thumb_data = %{cid: "blob123", mimeType: "image/jpeg"}

      assert {:ok, external_info} =
               ExternalInfo.new(%{
                 uri: "https://example.com",
                 title: "Example Website",
                 description: "This is an example website",
                 thumb: thumb_data
               })

      assert external_info.uri == "https://example.com"
      assert external_info.title == "Example Website"
      assert external_info.description == "This is an example website"
      assert external_info.thumb == thumb_data
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = ExternalInfo.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates valid external info" do
      assert %ExternalInfo{} =
               external_info =
               ExternalInfo.new!(%{
                 uri: "https://example.com",
                 title: "Example Website",
                 description: "This is an example website"
               })

      assert external_info.uri == "https://example.com"
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid external info/, fn ->
        ExternalInfo.new!(%{})
      end
    end
  end
end
