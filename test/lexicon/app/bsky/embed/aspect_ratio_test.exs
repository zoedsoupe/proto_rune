defmodule Lexicon.App.Bsky.Embed.AspectRatioTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Embed.AspectRatio

  describe "changeset/2" do
    test "validates required fields" do
      changeset = AspectRatio.changeset(%AspectRatio{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).width
      assert "can't be blank" in errors_on(changeset).height
    end

    test "validates positive values" do
      # Valid values
      changeset = AspectRatio.changeset(%AspectRatio{}, %{width: 16, height: 9})
      assert changeset.valid?

      # Invalid width
      changeset = AspectRatio.changeset(%AspectRatio{}, %{width: 0, height: 9})
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).width

      # Invalid height
      changeset = AspectRatio.changeset(%AspectRatio{}, %{width: 16, height: 0})
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).height

      # Negative values
      changeset = AspectRatio.changeset(%AspectRatio{}, %{width: -16, height: -9})
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).width
      assert "must be greater than 0" in errors_on(changeset).height
    end
  end

  describe "new/1" do
    test "creates a valid aspect ratio" do
      assert {:ok, aspect_ratio} = AspectRatio.new(%{width: 16, height: 9})
      assert aspect_ratio.width == 16
      assert aspect_ratio.height == 9
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = AspectRatio.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid aspect ratio" do
      assert %AspectRatio{} = aspect_ratio = AspectRatio.new!(%{width: 16, height: 9})
      assert aspect_ratio.width == 16
      assert aspect_ratio.height == 9
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid aspect ratio/, fn ->
        AspectRatio.new!(%{})
      end
    end
  end
end
