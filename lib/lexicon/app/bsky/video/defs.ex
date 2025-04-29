defmodule Lexicon.App.Bsky.Video.Defs do
  @moduledoc """
  Definitions for video-related data structures.

  NSID: app.bsky.video.defs
  """

  # Known values for job states
  @job_state_completed "JOB_STATE_COMPLETED"
  @job_state_failed "JOB_STATE_FAILED"

  # Export job state constants
  def job_state_completed, do: @job_state_completed
  def job_state_failed, do: @job_state_failed

  @doc """
  Checks if a job state value is valid.
  """
  def valid_job_state?(state) do
    state in [@job_state_completed, @job_state_failed]
  end

  @doc """
  Checks if a job state indicates completion (either successful or failed).
  """
  def job_completed?(state) do
    state in [@job_state_completed, @job_state_failed]
  end
end
