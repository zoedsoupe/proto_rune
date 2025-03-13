defmodule Lexicon.App.Bsky.Embed.VideoTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.AspectRatio
  alias Lexicon.App.Bsky.Embed.Video
  alias Lexicon.App.Bsky.Embed.VideoCaption

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Video.changeset(%Video{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).video
    end

    test "accepts valid attributes with minimal fields" do
      changeset =
        Video.changeset(%Video{}, %{
          video: %{cid: "blob123", mimeType: "video/mp4"}
        })

      assert changeset.valid?
    end

    test "accepts valid attributes with all fields" do
      changeset =
        Video.changeset(%Video{}, %{
          video: %{cid: "blob123", mimeType: "video/mp4"},
          alt: "A beautiful sunset video",
          aspect_ratio: %{width: 16, height: 9},
          captions: [
            %{lang: "en-US", file: %{cid: "caption1", mimeType: "text/vtt"}},
            %{lang: "es-MX", file: %{cid: "caption2", mimeType: "text/vtt"}}
          ]
        })

      assert changeset.valid?
    end

    test "validates captions count" do
      # Create too many captions (more than 20)
      captions =
        for i <- 1..21 do
          %{lang: "en-US", file: %{cid: "caption#{i}", mimeType: "text/vtt"}}
        end

      changeset =
        Video.changeset(%Video{}, %{
          video: %{cid: "blob123", mimeType: "video/mp4"},
          captions: captions
        })

      refute changeset.valid?
      assert "maximum of 20 captions allowed" in errors_on(changeset).captions
    end

    test "validates alt text length and graphemes" do
      video_data = %{cid: "blob123", mimeType: "video/mp4"}

      # Valid alt text
      changeset =
        Video.changeset(%Video{}, %{
          video: video_data,
          alt: "A valid alt text"
        })

      assert changeset.valid?

      # Alt text too long (characters)
      too_long_alt = String.duplicate("x", 10_001)

      changeset =
        Video.changeset(%Video{}, %{
          video: video_data,
          alt: too_long_alt
        })

      refute changeset.valid?
      assert "should be at most 10000 character(s)" in errors_on(changeset).alt

      # Alt text too long (graphemes)
      too_many_graphemes = String.duplicate("🚀", 1001)

      changeset =
        Video.changeset(%Video{}, %{
          video: video_data,
          alt: too_many_graphemes
        })

      refute changeset.valid?
      assert "should have at most 1000 graphemes" in errors_on(changeset).alt
    end

    test "validates embedded aspect ratio" do
      changeset =
        Video.changeset(%Video{}, %{
          video: %{cid: "blob123", mimeType: "video/mp4"},
          aspect_ratio: %{width: 0, height: 9}
        })

      refute changeset.valid?
      assert %{aspect_ratio: %{width: ["must be greater than 0"]}} = errors_on(changeset)
    end
  end

  describe "new/1" do
    test "creates a valid video with minimal fields" do
      video_data = %{cid: "blob123", mimeType: "video/mp4"}

      assert {:ok, video} = Video.new(%{video: video_data})
      assert video.video == video_data
      assert video.alt == nil
      assert video.aspect_ratio == nil
      assert video.captions == []
    end

    test "creates a valid video with all fields" do
      video_data = %{cid: "blob123", mimeType: "video/mp4"}
      alt_text = "A beautiful sunset video"
      aspect_ratio = %{width: 16, height: 9}

      captions = [
        %{lang: "en-US", file: %{cid: "caption1", mimeType: "text/vtt"}},
        %{lang: "fr-FR", file: %{cid: "caption2", mimeType: "text/vtt"}}
      ]

      assert {:ok, video} =
               Video.new(%{
                 video: video_data,
                 alt: alt_text,
                 aspect_ratio: aspect_ratio,
                 captions: captions
               })

      assert video.video == video_data
      assert video.alt == alt_text
      assert %AspectRatio{width: 16, height: 9} = video.aspect_ratio
      assert Enum.count(video.captions) == 2
      assert [%VideoCaption{}, %VideoCaption{}] = video.captions
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Video.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid video" do
      video_data = %{cid: "blob123", mimeType: "video/mp4"}

      assert %Video{} = video = Video.new!(%{video: video_data})
      assert video.video == video_data
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid video embed/, fn ->
        Video.new!(%{})
      end
    end
  end
end
