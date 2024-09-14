defmodule Bsky.Video do
  @moduledoc false

  import XRPC.DSL

  @doc """
  Get status details for a video processing job.

  https://docs.bsky.app/docs/api/app-bsky-video-get-job-status
  """
  defquery "app.bsky.video.getJobStatus", for: :todo do
    param(:job_id, {:required, :string})
  end

  @doc """
  Get video upload limits for the authenticated user.

  https://docs.bsky.app/docs/api/app-bsky-video-get-upload-limits
  """
  defquery("app.bsky.video.getUploadLimits", authenticated: true)

  @doc """
  Upload a video to be processed then stored on the PDS.

  https://docs.bsky.app/docs/api/app-bsky-video-upload-video
  """
  defprocedure "app.bsky.video.uploadVideo", authenticated: true do
    # TODO
    param(:any, :any)
  end
end
