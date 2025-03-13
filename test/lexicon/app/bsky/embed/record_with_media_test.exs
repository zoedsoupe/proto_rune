defmodule Lexicon.App.Bsky.Embed.RecordWithMediaTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.Record
  alias Lexicon.App.Bsky.Embed.RecordWithMedia

  describe "changeset/2" do
    test "validates required fields" do
      changeset = RecordWithMedia.changeset(%RecordWithMedia{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).record
      assert "can't be blank" in errors_on(changeset).media
    end

    test "validates record format" do
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: "invalid"},
          media: %{images: [%{image: %{cid: "blob1"}, alt: "Image 1"}]}
        })

      refute changeset.valid?
    end

    test "validates with images media" do
      # Valid images
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{images: [%{image: %{cid: "blob1"}, alt: "Image 1"}]}
        })

      assert changeset.valid?

      # Too many images
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{
            images: [
              %{image: %{cid: "blob1"}, alt: "Image 1"},
              %{image: %{cid: "blob2"}, alt: "Image 2"},
              %{image: %{cid: "blob3"}, alt: "Image 3"},
              %{image: %{cid: "blob4"}, alt: "Image 4"},
              %{image: %{cid: "blob5"}, alt: "Image 5"}
            ]
          }
        })

      refute changeset.valid?
      assert "images must be a list with a maximum of 4 items" in errors_on(changeset).media
    end

    test "validates with video media" do
      # Valid video
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{video: %{cid: "blob123", mimeType: "video/mp4"}}
        })

      assert changeset.valid?

      # Invalid video
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{video: "not-a-map"}
        })

      refute changeset.valid?
      assert "video must be a valid blob reference" in errors_on(changeset).media
    end

    test "validates with external media" do
      # Valid external
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{external: %{uri: "https://example.com", title: "Example", description: "Desc"}}
        })

      assert changeset.valid?

      # Invalid external - missing URI
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{external: %{title: "Example", description: "Desc"}}
        })

      refute changeset.valid?
      assert "external must be a valid external reference with a URI" in errors_on(changeset).media
    end

    test "validates with invalid media type" do
      changeset =
        RecordWithMedia.changeset(%RecordWithMedia{}, %{
          record: %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}},
          media: %{unknown_type: "invalid"}
        })

      refute changeset.valid?
      assert "must be a valid Images, Video, or External embed" in errors_on(changeset).media
    end
  end

  describe "new/1" do
    test "creates a valid record with images media" do
      record_data = %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}}
      media_data = %{images: [%{image: %{cid: "blob1"}, alt: "Image 1"}]}

      assert {:ok, record_with_media} =
               RecordWithMedia.new(%{
                 record: record_data,
                 media: media_data
               })

      assert %Record{} = record_with_media.record
      assert record_with_media.media == media_data
    end

    test "creates a valid record with video media" do
      record_data = %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}}
      media_data = %{video: %{cid: "blob123", mimeType: "video/mp4"}}

      assert {:ok, record_with_media} =
               RecordWithMedia.new(%{
                 record: record_data,
                 media: media_data
               })

      assert %Record{} = record_with_media.record
      assert record_with_media.media == media_data
    end

    test "creates a valid record with external media" do
      record_data = %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}}
      media_data = %{external: %{uri: "https://example.com", title: "Example", description: "Desc"}}

      assert {:ok, record_with_media} =
               RecordWithMedia.new(%{
                 record: record_data,
                 media: media_data
               })

      assert %Record{} = record_with_media.record
      assert record_with_media.media == media_data
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = RecordWithMedia.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid record with media" do
      record_data = %{record: %{uri: "at://did:plc:1234/app.bsky.feed.post/abc", cid: "bafyabc123"}}
      media_data = %{images: [%{image: %{cid: "blob1"}, alt: "Image 1"}]}

      assert %RecordWithMedia{} =
               record_with_media =
               RecordWithMedia.new!(%{
                 record: record_data,
                 media: media_data
               })

      assert %Record{} = record_with_media.record
      assert record_with_media.media == media_data
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid record with media embed/, fn ->
        RecordWithMedia.new!(%{})
      end
    end
  end
end
