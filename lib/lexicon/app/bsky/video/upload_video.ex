defmodule Lexicon.App.Bsky.Video.UploadVideo do
  @moduledoc """
  Procedure for uploading a video for processing.

  NSID: app.bsky.video.uploadVideo
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          video: binary(),
          job_id: String.t() | nil,
          duration_ms: integer() | nil
        }

  @primary_key false
  embedded_schema do
    field :video, :binary
    field :job_id, :string
    field :duration_ms, :integer
  end

  @doc """
  Creates a changeset for validating video upload request.
  """
  def changeset(upload_video, attrs) do
    upload_video
    |> cast(attrs, [:video, :job_id, :duration_ms])
    |> validate_required([:video])
    |> validate_number(:duration_ms, greater_than: 0)
  end

  @doc """
  Validates a video upload request structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end

  @doc """
  Creates a response for a successful video upload.
  """
  def response(job_id) do
    %{
      "job_id" => job_id
    }
  end
end
