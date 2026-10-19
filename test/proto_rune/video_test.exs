defmodule ProtoRune.Bsky.VideoTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Bsky.Video

  @session %ProtoRune.Atproto.Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  @job_status %{"jobId" => "job1", "did" => "did:plc:test", "state" => "JOB_STATE_ENQUEUED"}

  setup do
    test_pid = self()

    http =
      fake_http(fn method, url, opts ->
        send(test_pid, {:request, method, url, opts})
        {:ok, %{status: 200, headers: %{}, body: %{"jobStatus" => @job_status}}}
      end)

    {:ok, http: http}
  end

  describe "service_url/0" do
    test "points at the video service" do
      assert Video.service_url() == "https://video.bsky.app"
    end
  end

  describe "upload_video/4" do
    test "posts the raw mp4 to the video service", %{http: http} do
      assert {:ok, %{job_status: %{job_id: "job1", did: "did:plc:test", state: "JOB_STATE_ENQUEUED"}}} =
               Video.upload_video(@session, "mp4 bytes", "video/mp4", http: http)

      assert_received {:request, :post, url, opts}
      assert url == "https://video.bsky.app/xrpc/app.bsky.video.uploadVideo"
      assert opts[:body] == "mp4 bytes"
      assert {"content-type", "video/mp4"} in opts[:headers]
      assert {"authorization", "Bearer token123"} in opts[:headers]
    end
  end
end
