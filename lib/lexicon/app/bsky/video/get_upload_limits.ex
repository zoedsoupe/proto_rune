defmodule Lexicon.App.Bsky.Video.GetUploadLimits do
  @moduledoc """
  Get limits for video uploads for the requesting account.

  NSID: app.bsky.video.getUploadLimits
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          max_count_daily: integer(),
          max_bytes_daily: integer(),
          max_bytes_per_upload: integer(),
          used_count_daily: integer(),
          used_bytes_daily: integer()
        }

  @primary_key false
  embedded_schema do
    field :max_count_daily, :integer
    field :max_bytes_daily, :integer
    field :max_bytes_per_upload, :integer
    field :used_count_daily, :integer
    field :used_bytes_daily, :integer
  end

  @doc """
  Creates a changeset for validating upload limits.
  """
  def changeset(upload_limits, attrs) do
    upload_limits
    |> cast(attrs, [
      :max_count_daily,
      :max_bytes_daily,
      :max_bytes_per_upload,
      :used_count_daily,
      :used_bytes_daily
    ])
    |> validate_required([
      :max_count_daily,
      :max_bytes_daily,
      :max_bytes_per_upload,
      :used_count_daily,
      :used_bytes_daily
    ])
    |> validate_number(:max_count_daily, greater_than_or_equal_to: 0)
    |> validate_number(:max_bytes_daily, greater_than_or_equal_to: 0)
    |> validate_number(:max_bytes_per_upload, greater_than_or_equal_to: 0)
    |> validate_number(:used_count_daily, greater_than_or_equal_to: 0)
    |> validate_number(:used_bytes_daily, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates upload limits structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end

  @doc """
  Creates a response with upload limits.
  """
  def response(limits) do
    %{
      "max_count_daily" => limits.max_count_daily,
      "max_bytes_daily" => limits.max_bytes_daily,
      "max_bytes_per_upload" => limits.max_bytes_per_upload,
      "used_count_daily" => limits.used_count_daily,
      "used_bytes_daily" => limits.used_bytes_daily
    }
  end
end
