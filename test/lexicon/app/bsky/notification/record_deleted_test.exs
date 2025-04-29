defmodule Lexicon.App.Bsky.Notification.RecordDeletedTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Notification.RecordDeleted

  describe "changeset/2" do
    test "accepts empty attributes" do
      changeset = RecordDeleted.changeset(%RecordDeleted{}, %{})
      assert changeset.valid?
    end

    test "ignores unexpected attributes" do
      changeset = RecordDeleted.changeset(%RecordDeleted{}, %{unexpected: "value"})
      assert changeset.valid?
      assert get_change(changeset, :unexpected) == nil
    end
  end

  describe "validate/1" do
    test "validates an empty map" do
      assert {:ok, record_deleted} = RecordDeleted.validate(%{})
      assert record_deleted.__struct__ == RecordDeleted
    end

    test "validates with additional fields" do
      assert {:ok, record_deleted} = RecordDeleted.validate(%{unexpected: "value"})
      assert record_deleted.__struct__ == RecordDeleted
      assert Map.get(record_deleted, :unexpected) == nil
    end
  end

  # Helper functions
  defp get_change(changeset, field) do
    Ecto.Changeset.get_change(changeset, field)
  end
end
