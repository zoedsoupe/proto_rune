defmodule Lexicon.App.Bsky.Video.GetJobStatus do
  @moduledoc """
  Query to get the status of a video processing job.

  NSID: app.bsky.video.getJobStatus
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Video.JobStatus

  @type t :: %__MODULE__{
          job_id: String.t(),
          status: JobStatus.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :job_id, :string
    embeds_one :status, JobStatus
  end

  @doc """
  Creates a changeset for validating a getJobStatus query.
  """
  def changeset(get_job_status, attrs) do
    get_job_status
    |> cast(attrs, [:job_id])
    |> cast_embed(:status, required: false)
    |> validate_required([:job_id])
  end

  @doc """
  Validates a getJobStatus query structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end

  @doc """
  Creates a response for a video processing job status.
  """
  def response(job_id, status) do
    %{
      "job_id" => job_id,
      "status" => status
    }
  end
end
