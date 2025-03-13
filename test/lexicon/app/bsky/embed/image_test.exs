defmodule Lexicon.App.Bsky.Embed.ImageTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.AspectRatio
  alias Lexicon.App.Bsky.Embed.Image

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Image.changeset(%Image{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).image
      assert "can't be blank" in errors_on(changeset).alt
    end

    test "accepts valid attributes" do
      # Without aspect_ratio
      changeset =
        Image.changeset(%Image{}, %{
          image: %{cid: "blob123", mimeType: "image/jpeg"},
          alt: "A beautiful sunset"
        })

      assert changeset.valid?

      # With aspect_ratio
      changeset =
        Image.changeset(%Image{}, %{
          image: %{cid: "blob123", mimeType: "image/jpeg"},
          alt: "A beautiful sunset",
          aspect_ratio: %{
            width: 16,
            height: 9
          }
        })

      assert changeset.valid?
    end

    test "validates embedded aspect_ratio" do
      changeset =
        Image.changeset(%Image{}, %{
          image: %{cid: "blob123", mimeType: "image/jpeg"},
          alt: "A beautiful sunset",
          aspect_ratio: %{
            width: 0,
            height: 9
          }
        })

      refute changeset.valid?
      assert %{aspect_ratio: %{width: ["must be greater than 0"]}} = errors_on(changeset)
    end
  end

  describe "new/1" do
    test "creates a valid image without aspect_ratio" do
      image_data = %{cid: "blob123", mimeType: "image/jpeg"}
      alt_text = "A beautiful sunset"

      assert {:ok, image} =
               Image.new(%{
                 image: image_data,
                 alt: alt_text
               })

      assert image.image == image_data
      assert image.alt == alt_text
      assert image.aspect_ratio == nil
    end

    test "creates a valid image with aspect_ratio" do
      image_data = %{cid: "blob123", mimeType: "image/jpeg"}
      alt_text = "A beautiful sunset"
      aspect_ratio = %{width: 16, height: 9}

      assert {:ok, image} =
               Image.new(%{
                 image: image_data,
                 alt: alt_text,
                 aspect_ratio: aspect_ratio
               })

      assert image.image == image_data
      assert image.alt == alt_text
      assert %AspectRatio{width: 16, height: 9} = image.aspect_ratio
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Image.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid image" do
      image_data = %{cid: "blob123", mimeType: "image/jpeg"}
      alt_text = "A beautiful sunset"

      assert %Image{} =
               image =
               Image.new!(%{
                 image: image_data,
                 alt: alt_text
               })

      assert image.image == image_data
      assert image.alt == alt_text
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid image/, fn ->
        Image.new!(%{})
      end
    end
  end
end
