defmodule Lexicon.App.Bsky.Video.GetJobStatusTest do
  use ExUnit.Case, async: true

  alias Lexicon.App.Bsky.Video.GetJobStatus

  describe "changeset/2" do
    test "validates required fields" do
      changeset = GetJobStatus.changeset(%GetJobStatus{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).job_id
    end

    test "accepts valid job_id" do
      changeset = GetJobStatus.changeset(%GetJobStatus{}, %{job_id: "valid-job-id"})
      assert changeset.valid?
    end

    test "accepts status when provided" do
      status = %{
        job_id: "job-123",
        did: "did:plc:1234",
        state: "JOB_STATE_COMPLETED",
        progress: 100
      }

      changeset =
        GetJobStatus.changeset(%GetJobStatus{}, %{
          job_id: "valid-job-id",
          status: status
        })

      assert changeset.valid?
    end
  end

  describe "validate/1" do
    test "validates a map against the schema" do
      valid_map = %{
        job_id: "valid-job-id"
      }

      assert {:ok, get_job_status} = GetJobStatus.validate(valid_map)
      assert get_job_status.job_id == "valid-job-id"
    end

    test "validates with status included" do
      valid_map = %{
        job_id: "valid-job-id",
        status: %{
          job_id: "job-123",
          did: "did:plc:1234",
          state: "JOB_STATE_COMPLETED",
          progress: 100
        }
      }

      assert {:ok, get_job_status} = GetJobStatus.validate(valid_map)
      assert get_job_status.job_id == "valid-job-id"
      assert get_job_status.status != nil
      assert get_job_status.status.state == "JOB_STATE_COMPLETED"
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = GetJobStatus.validate(%{})
      refute changeset.valid?
    end
  end

  describe "response/2" do
    test "creates a valid response structure" do
      job_id = "valid-job-id"

      status = %{
        state: "complete",
        duration_ms: 30_000,
        width: 1920,
        height: 1080,
        mime_type: "video/mp4"
      }

      response = GetJobStatus.response(job_id, status)

      assert response["job_id"] == job_id
      assert response["status"] == status
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
