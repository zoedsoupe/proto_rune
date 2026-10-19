defmodule ProtoRune.Bsky.Video do
  @moduledoc """
  Video endpoints of the Bluesky lexicon (`app.bsky.video.*`).

  Videos are processed by a dedicated service, `service_url/0`
  (`https://video.bsky.app`), not by the PDS. `upload_video/4` posts
  the raw mp4 there and returns the processing `jobStatus`; poll
  `get_job_status/3` with `base_url: ProtoRune.Bsky.Video.service_url()`
  until the state is `"JOB_STATE_COMPLETED"` and the response carries
  the processed `blob` to embed. `get_upload_limits/3`, in contrast, is
  implemented by the PDS and needs no `:base_url`.

  A simpler alternative is `ProtoRune.Bsky.post/3` with the `:video`
  option: it uploads the mp4 to the PDS as a regular blob and embeds
  it, and the video service picks it up for processing after the post
  is created. `upload_video/4` is the recommended flow when the post
  should only go out once the video is processed.

  The video service authenticates with the session's regular
  credentials (`ProtoRune.Session.authorization_headers/3`): a `Bearer`
  access token for app-password sessions, a DPoP proof for OAuth
  sessions. The official clients mint a dedicated service-auth token
  with `com.atproto.server.getServiceAuth` instead; that endpoint is
  not implemented here.

  The generated XRPC functions are public and called as
  `Video.endpoint(session, %{param: value})`.
  """

  import ProtoRune.XRPC.DSL

  alias ProtoRune.Session
  alias ProtoRune.XRPC
  alias ProtoRune.XRPC.Procedure

  @video_service "https://video.bsky.app"

  @doc """
  The base URL of the Bluesky video service.
  """
  @spec service_url() :: String.t()
  def service_url, do: @video_service

  @doc """
  Get status details for a video processing job.

  Served by the video service, so pass its base URL in opts:

      {:ok, %{job_status: status}} =
        Video.get_job_status(session, %{job_id: job_id},
          base_url: ProtoRune.Bsky.Video.service_url()
        )

  https://docs.bsky.app/docs/api/app-bsky-video-get-job-status
  """
  defquery "app.bsky.video.getJobStatus" do
    param :job_id, {:required, :string}
  end

  @doc """
  Get video upload limits for the authenticated user.

  Implemented by the PDS, so no `:base_url` option is needed.

  https://docs.bsky.app/docs/api/app-bsky-video-get-upload-limits
  """
  defquery "app.bsky.video.getUploadLimits", authenticated: true

  @doc """
  Uploads a video to the Bluesky video service for processing.

  `data` is the raw mp4 bytes and `content_type` its MIME type
  (`"video/mp4"`). Returns `{:ok, %{job_status: status}}`; poll
  `get_job_status/3` (with `base_url: service_url()`) until
  `status.state` is `"JOB_STATE_COMPLETED"` and `status.blob` holds the
  processed blob reference, ready for `ProtoRune.Bsky.Embed.video/2`.

  ## Options

    * `:http` - options forwarded to `ProtoRune.HTTPClient.request/3`.

  https://docs.bsky.app/docs/api/app-bsky-video-upload-video

  ## Examples

      {:ok, %{job_status: %{job_id: job_id}}} =
        Video.upload_video(session, mp4_data, "video/mp4")
  """
  @spec upload_video(Session.t(), binary(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def upload_video(session, data, content_type \\ "video/mp4", opts \\ [])
      when is_binary(data) and is_binary(content_type) do
    base_url = Path.join(@video_service, "xrpc")
    url = Path.join(base_url, "app.bsky.video.uploadVideo")

    with {:ok, headers, session} <- Session.authorization_headers(session, "POST", url) do
      "app.bsky.video.uploadVideo"
      |> Procedure.new(base_url: base_url)
      |> Procedure.put_raw_body(data)
      |> Procedure.put_header("content-type", content_type)
      |> then(&%{&1 | headers: Map.merge(&1.headers, headers)})
      |> XRPC.Client.execute(session: session, http: Keyword.get(opts, :http, []))
    end
  end
end
