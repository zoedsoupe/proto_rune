defmodule Lexicon.App.Bsky.Richtext.ByteSliceTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Richtext.ByteSlice

  describe "changeset/2" do
    test "validates required fields" do
      changeset = ByteSlice.changeset(%ByteSlice{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).byte_start
      assert "can't be blank" in errors_on(changeset).byte_end
    end

    test "validates non-negative values" do
      # Valid values
      changeset = ByteSlice.changeset(%ByteSlice{}, %{byte_start: 0, byte_end: 10})
      assert changeset.valid?

      # Negative byte_start
      changeset = ByteSlice.changeset(%ByteSlice{}, %{byte_start: -1, byte_end: 10})
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).byte_start

      # Negative byte_end
      changeset = ByteSlice.changeset(%ByteSlice{}, %{byte_start: 0, byte_end: -1})
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).byte_end
    end

    test "validates byte_start <= byte_end" do
      # Valid: start equals end
      changeset = ByteSlice.changeset(%ByteSlice{}, %{byte_start: 10, byte_end: 10})
      assert changeset.valid?

      # Valid: start less than end
      changeset = ByteSlice.changeset(%ByteSlice{}, %{byte_start: 0, byte_end: 10})
      assert changeset.valid?

      # Invalid: start greater than end
      changeset = ByteSlice.changeset(%ByteSlice{}, %{byte_start: 10, byte_end: 5})
      refute changeset.valid?
      assert "must be greater than or equal to byte_start" in errors_on(changeset).byte_end
    end
  end

  describe "new/1" do
    test "creates a valid byte slice" do
      assert {:ok, byte_slice} = ByteSlice.new(%{byte_start: 0, byte_end: 10})
      assert byte_slice.byte_start == 0
      assert byte_slice.byte_end == 10
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = ByteSlice.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid byte slice" do
      assert %ByteSlice{} = byte_slice = ByteSlice.new!(%{byte_start: 0, byte_end: 10})
      assert byte_slice.byte_start == 0
      assert byte_slice.byte_end == 10
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid byte slice/, fn ->
        ByteSlice.new!(%{})
      end
    end
  end
end
