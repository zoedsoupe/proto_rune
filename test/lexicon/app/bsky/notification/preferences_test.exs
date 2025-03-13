defmodule Lexicon.App.Bsky.Notification.PreferencesTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Notification.Preferences

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Preferences.changeset(%Preferences{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).priority
    end

    test "validates priority" do
      # True value
      changeset = Preferences.changeset(%Preferences{}, %{priority: true})
      assert changeset.valid?

      # False value
      changeset = Preferences.changeset(%Preferences{}, %{priority: false})
      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates valid preferences with priority true" do
      assert {:ok, preferences} = Preferences.new(%{priority: true})
      assert preferences.priority == true
    end

    test "creates valid preferences with priority false" do
      assert {:ok, preferences} = Preferences.new(%{priority: false})
      assert preferences.priority == false
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Preferences.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates valid preferences" do
      assert %Preferences{} = preferences = Preferences.new!(%{priority: true})
      assert preferences.priority == true
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid notification preferences/, fn ->
        Preferences.new!(%{})
      end
    end
  end
end
