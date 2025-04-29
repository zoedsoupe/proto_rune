defmodule Lexicon.App.Bsky.Video.Defs.JobStatus do
  @moduledoc """
  Status information for a video processing job.

  Part of app.bsky.video.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Video.Defs

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
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
    |> validate_number(:progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_state_and_error()
  end

  defp validate_state_and_error(changeset) do
    state = get_field(changeset, :state)
    error = get_field(changeset, :error)

    # If state is failed, there should be an error message
    if state == Defs.job_state_failed() && is_nil(error) do
      add_error(changeset, :error, "is required when job state is failed")
    else
      changeset
    end
  end

  @doc """
  Validates a job status structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
