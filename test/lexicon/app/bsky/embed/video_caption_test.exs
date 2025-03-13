defmodule Lexicon.App.Bsky.Embed.VideoCaptionTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.VideoCaption

  describe "changeset/2" do
    test "validates required fields" do
      changeset = VideoCaption.changeset(%VideoCaption{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).lang
      assert "can't be blank" in errors_on(changeset).file
    end

    test "validates language format" do
      file_data = %{cid: "blob123", mimeType: "text/vtt"}

      # Valid language codes
      for lang <- ["en", "es", "fr", "en-US", "es-MX", "fr-CA"] do
        changeset =
          VideoCaption.changeset(%VideoCaption{}, %{
            lang: lang,
            file: file_data
          })

        assert changeset.valid?
      end

      # Invalid language codes
      for lang <- ["invalid", "e", "123", "en_US", "EN"] do
        changeset =
          VideoCaption.changeset(%VideoCaption{}, %{
            lang: lang,
            file: file_data
          })

        refute changeset.valid?
        assert "must be a valid language code" in errors_on(changeset).lang
      end
    end
  end

  describe "new/1" do
    test "creates a valid video caption" do
      lang = "en-US"
      file_data = %{cid: "blob123", mimeType: "text/vtt"}

      assert {:ok, caption} =
               VideoCaption.new(%{
                 lang: lang,
                 file: file_data
               })

      assert caption.lang == lang
      assert caption.file == file_data
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = VideoCaption.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid video caption" do
      lang = "en-US"
      file_data = %{cid: "blob123", mimeType: "text/vtt"}

      assert %VideoCaption{} =
               caption =
               VideoCaption.new!(%{
                 lang: lang,
                 file: file_data
               })

      assert caption.lang == lang
      assert caption.file == file_data
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid video caption/, fn ->
        VideoCaption.new!(%{})
      end
    end
  end
end
