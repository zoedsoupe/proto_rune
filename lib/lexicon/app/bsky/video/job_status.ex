defmodule Lexicon.App.Bsky.Video.JobStatus do
  @moduledoc """
  Status of a video processing job.

  NSID: app.bsky.video.defs#jobStatus
  """

  use Ecto.Schema

  import Ecto.Changeset

  # Known completed states
  @known_states ~w(JOB_STATE_COMPLETED JOB_STATE_FAILED)

  @type t :: %__MODULE__{
          job_id: String.t(),
          did: String.t(),
          state: String.t(),
          progress: integer() | nil,
          blob: map() | nil,
          error: String.t() | nil,
          message: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :job_id, :string
    field :did, :string
    field :state, :string
    field :progress, :integer
    field :blob, :map
    field :error, :string
    field :message, :string
  end

  @doc """
  Creates a changeset for validating a job status.
  """
  def changeset(job_status, attrs) do
    job_status
    |> cast(attrs, [:job_id, :did, :state, :progress, :blob, :error, :message])
    |> validate_required([:job_id, :did, :state])
    |> validate_format(:did, ~r/^did:/, message: "must be a valid DID format")
    |> validate_state()
    |> validate_progress()
  end

  defp validate_state(changeset) do
    # All states are valid, but we could validate known states if needed
    changeset
  end

  defp validate_progress(changeset) do
    if _progress = get_field(changeset, :progress) do
      validate_number(changeset, :progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    else
      changeset
    end
  end

  @doc """
  Checks if the job status represents a completed job.
  """
  def completed?(%__MODULE__{state: "JOB_STATE_COMPLETED"}), do: true
  def completed?(_), do: false

  @doc """
  Checks if the job status represents a failed job.
  """
  def failed?(%__MODULE__{state: "JOB_STATE_FAILED"}), do: true
  def failed?(_), do: false

  @doc """
  Checks if the job status represents an in-progress job.
  """
  def in_progress?(%__MODULE__{} = job) do
    not (completed?(job) or failed?(job))
  end

  @doc """
  Returns a list of known final states.
  """
  def known_states, do: @known_states

  @doc """
  Creates a new job status with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new job status, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, job_status} -> job_status
      {:error, changeset} -> raise "Invalid job status: #{inspect(changeset.errors)}"
    end
  end
end
