defmodule Lexicon.App.Bsky.Video.GetUploadLimitsTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Video.GetUploadLimits

  describe "changeset/2" do
    test "validates required fields" do
      changeset = GetUploadLimits.changeset(%GetUploadLimits{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).max_count_daily
      assert "can't be blank" in errors_on(changeset).max_bytes_daily
      assert "can't be blank" in errors_on(changeset).max_bytes_per_upload
      assert "can't be blank" in errors_on(changeset).used_count_daily
      assert "can't be blank" in errors_on(changeset).used_bytes_daily
    end

    test "validates non-negative values" do
      valid_attrs = %{
        max_count_daily: 10,
        max_bytes_daily: 100_000_000,
        max_bytes_per_upload: 10_000_000,
        used_count_daily: 5,
        used_bytes_daily: 50_000_000
      }

      changeset = GetUploadLimits.changeset(%GetUploadLimits{}, valid_attrs)
      assert changeset.valid?

      # Test negative values
      invalid_attrs = %{
        max_count_daily: -1,
        max_bytes_daily: 100_000_000,
        max_bytes_per_upload: 10_000_000,
        used_count_daily: 5,
        used_bytes_daily: 50_000_000
      }

      changeset = GetUploadLimits.changeset(%GetUploadLimits{}, invalid_attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).max_count_daily
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        max_count_daily: 10,
        max_bytes_daily: 100_000_000,
        max_bytes_per_upload: 10_000_000,
        used_count_daily: 5,
        used_bytes_daily: 50_000_000
      }

      assert {:ok, limits} = GetUploadLimits.validate(valid_map)
      assert limits.max_count_daily == 10
      assert limits.max_bytes_daily == 100_000_000
      assert limits.max_bytes_per_upload == 10_000_000
      assert limits.used_count_daily == 5
      assert limits.used_bytes_daily == 50_000_000
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = GetUploadLimits.validate(%{})
      refute changeset.valid?
    end
  end

  describe "response/1" do
    test "creates a valid response structure" do
      limits = %GetUploadLimits{
        max_count_daily: 10,
        max_bytes_daily: 100_000_000,
        max_bytes_per_upload: 10_000_000,
        used_count_daily: 5,
        used_bytes_daily: 50_000_000
      }

      response = GetUploadLimits.response(limits)

      assert response["max_count_daily"] == 10
      assert response["max_bytes_daily"] == 100_000_000
      assert response["max_bytes_per_upload"] == 10_000_000
      assert response["used_count_daily"] == 5
      assert response["used_bytes_daily"] == 50_000_000
    end
  end

  # Helper functions
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
