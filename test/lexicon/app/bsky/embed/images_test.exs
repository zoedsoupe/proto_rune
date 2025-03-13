defmodule Lexicon.App.Bsky.Embed.ImagesTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.Image
  alias Lexicon.App.Bsky.Embed.Images

  describe "changeset/2" do
    test "validates required images field" do
      changeset = Images.changeset(%Images{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).images
    end

    test "validates images count" do
      # Valid with 1 image
      changeset =
        Images.changeset(%Images{}, %{
          images: [
            %{image: %{cid: "blob123"}, alt: "Image 1"}
          ]
        })

      assert changeset.valid?

      # Valid with 4 images (max)
      changeset =
        Images.changeset(%Images{}, %{
          images: [
            %{image: %{cid: "blob1"}, alt: "Image 1"},
            %{image: %{cid: "blob2"}, alt: "Image 2"},
            %{image: %{cid: "blob3"}, alt: "Image 3"},
            %{image: %{cid: "blob4"}, alt: "Image 4"}
          ]
        })

      assert changeset.valid?

      # Invalid with 5 images (too many)
      changeset =
        Images.changeset(%Images{}, %{
          images: [
            %{image: %{cid: "blob1"}, alt: "Image 1"},
            %{image: %{cid: "blob2"}, alt: "Image 2"},
            %{image: %{cid: "blob3"}, alt: "Image 3"},
            %{image: %{cid: "blob4"}, alt: "Image 4"},
            %{image: %{cid: "blob5"}, alt: "Image 5"}
          ]
        })

      refute changeset.valid?
      assert "maximum of 4 images allowed" in errors_on(changeset).images
    end

    test "validates each image in the list" do
      # Missing required fields in an image
      changeset =
        Images.changeset(%Images{}, %{
          images: [
            %{image: %{cid: "blob1"}, alt: "Image 1"},
            # Missing required fields
            %{}
          ]
        })

      refute changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a valid images object" do
      image_data = [
        %{image: %{cid: "blob1"}, alt: "Image 1"},
        %{image: %{cid: "blob2"}, alt: "Image 2"}
      ]

      assert {:ok, images} = Images.new(%{images: image_data})
      assert Enum.count(images.images) == 2
      assert [%Image{}, %Image{}] = images.images
      assert Enum.at(images.images, 0).alt == "Image 1"
      assert Enum.at(images.images, 1).alt == "Image 2"
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Images.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid images object" do
      image_data = [
        %{image: %{cid: "blob1"}, alt: "Image 1"}
      ]

      assert %Images{} = images = Images.new!(%{images: image_data})
      assert Enum.count(images.images) == 1
      assert [%Image{}] = images.images
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid images/, fn ->
        Images.new!(%{})
      end
    end
  end
end
