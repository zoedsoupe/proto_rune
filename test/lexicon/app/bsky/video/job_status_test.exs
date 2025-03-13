defmodule Lexicon.App.Bsky.Video.JobStatusTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Video.JobStatus

  describe "changeset/2" do
    test "validates required fields" do
      changeset = JobStatus.changeset(%JobStatus{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).job_id
      assert "can't be blank" in errors_on(changeset).did
      assert "can't be blank" in errors_on(changeset).state
    end

    test "validates DID format" do
      # Valid DID
      changeset =
        JobStatus.changeset(%JobStatus{}, %{
          job_id: "job123",
          did: "did:plc:1234abcd",
          state: "PROCESSING"
        })

      assert changeset.valid?

      # Invalid DID
      changeset =
        JobStatus.changeset(%JobStatus{}, %{
          job_id: "job123",
          did: "invalid-did",
          state: "PROCESSING"
        })

      refute changeset.valid?
      assert "must be a valid DID format" in errors_on(changeset).did
    end

    test "validates progress range" do
      base_attrs = %{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "PROCESSING"
      }

      # Valid progress values
      for progress <- [0, 50, 100] do
        changeset = JobStatus.changeset(%JobStatus{}, Map.put(base_attrs, :progress, progress))
        assert changeset.valid?
      end

      # Invalid progress - below minimum
      changeset = JobStatus.changeset(%JobStatus{}, Map.put(base_attrs, :progress, -1))
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).progress

      # Invalid progress - above maximum
      changeset = JobStatus.changeset(%JobStatus{}, Map.put(base_attrs, :progress, 101))
      refute changeset.valid?
      assert "must be less than or equal to 100" in errors_on(changeset).progress
    end

    test "accepts known state values" do
      base_attrs = %{
        job_id: "job123",
        did: "did:plc:1234abcd"
      }

      # Completed state
      changeset = JobStatus.changeset(%JobStatus{}, Map.put(base_attrs, :state, "JOB_STATE_COMPLETED"))
      assert changeset.valid?

      # Failed state
      changeset = JobStatus.changeset(%JobStatus{}, Map.put(base_attrs, :state, "JOB_STATE_FAILED"))
      assert changeset.valid?

      # In-progress state
      changeset = JobStatus.changeset(%JobStatus{}, Map.put(base_attrs, :state, "PROCESSING"))
      assert changeset.valid?
    end
  end

  describe "state helper functions" do
    test "completed?/1" do
      completed_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_COMPLETED"
      }

      assert JobStatus.completed?(completed_job)

      in_progress_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "PROCESSING"
      }

      refute JobStatus.completed?(in_progress_job)

      failed_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_FAILED"
      }

      refute JobStatus.completed?(failed_job)
    end

    test "failed?/1" do
      failed_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_FAILED"
      }

      assert JobStatus.failed?(failed_job)

      in_progress_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "PROCESSING"
      }

      refute JobStatus.failed?(in_progress_job)

      completed_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_COMPLETED"
      }

      refute JobStatus.failed?(completed_job)
    end

    test "in_progress?/1" do
      in_progress_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "PROCESSING"
      }

      assert JobStatus.in_progress?(in_progress_job)

      completed_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_COMPLETED"
      }

      refute JobStatus.in_progress?(completed_job)

      failed_job = %JobStatus{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_FAILED"
      }

      refute JobStatus.in_progress?(failed_job)
    end
  end

  describe "new/1" do
    test "creates a valid job status with minimal fields" do
      attrs = %{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "PROCESSING"
      }

      assert {:ok, job} = JobStatus.new(attrs)
      assert job.job_id == attrs.job_id
      assert job.did == attrs.did
      assert job.state == attrs.state
      assert job.progress == nil
      assert job.blob == nil
      assert job.error == nil
      assert job.message == nil
    end

    test "creates a valid job status with all fields" do
      attrs = %{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "JOB_STATE_COMPLETED",
        progress: 100,
        blob: %{cid: "blob123"},
        error: nil,
        message: "Processing complete"
      }

      assert {:ok, job} = JobStatus.new(attrs)
      assert job.job_id == attrs.job_id
      assert job.did == attrs.did
      assert job.state == attrs.state
      assert job.progress == attrs.progress
      assert job.blob == attrs.blob
      assert job.error == attrs.error
      assert job.message == attrs.message
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = JobStatus.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid job status" do
      attrs = %{
        job_id: "job123",
        did: "did:plc:1234abcd",
        state: "PROCESSING"
      }

      assert %JobStatus{} = job = JobStatus.new!(attrs)
      assert job.job_id == attrs.job_id
      assert job.did == attrs.did
      assert job.state == attrs.state
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid job status/, fn ->
        JobStatus.new!(%{})
      end
    end
  end
end
