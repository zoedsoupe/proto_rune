defmodule Lexicon.App.Bsky.Video.UploadVideoTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Video.UploadVideo

  describe "changeset/2" do
    test "validates required fields" do
      changeset = UploadVideo.changeset(%UploadVideo{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).video
    end

    test "validates duration_ms is positive when provided" do
      # Valid
      valid_attrs = %{
        video: <<1, 2, 3>>,
        duration_ms: 5000
      }

      changeset = UploadVideo.changeset(%UploadVideo{}, valid_attrs)
      assert changeset.valid?

      # Invalid duration (not positive)
      invalid_attrs = %{
        video: <<1, 2, 3>>,
        duration_ms: 0
      }

      changeset = UploadVideo.changeset(%UploadVideo{}, invalid_attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).duration_ms
    end

    test "accepts video without duration" do
      valid_attrs = %{
        video: <<1, 2, 3>>
      }

      changeset = UploadVideo.changeset(%UploadVideo{}, valid_attrs)
      assert changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        video: <<1, 2, 3>>,
        duration_ms: 5000
      }

      assert {:ok, upload} = UploadVideo.validate(valid_map)
      assert upload.video == <<1, 2, 3>>
      assert upload.duration_ms == 5000
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = UploadVideo.validate(%{})
      refute changeset.valid?
    end
  end

  describe "response/1" do
    test "creates a valid response structure" do
      job_id = "job-123456"
      response = UploadVideo.response(job_id)

      assert response["job_id"] == job_id
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
