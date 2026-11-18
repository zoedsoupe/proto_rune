defmodule ProtoRune.Atproto.ServerTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Server
  alias ProtoRune.Atproto.Session

  @session %Session{
    access_jwt: "token123",
    refresh_jwt: "refresh123",
    did: "did:plc:test",
    handle: "alice.test",
    service_url: "https://pds.test/xrpc"
  }

  test "get_service_auth uses the session and preserves its query params" do
    http =
      fake_http(fn :get, url, opts ->
        send(self(), {:request, url, opts})
        {:ok, %{status: 200, body: %{token: "signed-token"}}}
      end)

    assert {:ok, %{token: "signed-token"}} =
             Server.get_service_auth(
               @session,
               %{aud: "did:web:service.test", exp: 1_800_000_000, lxm: "app.bsky.feed.getTimeline"},
               http: http
             )

    assert_received {:request, url, opts}
    assert url =~ "/com.atproto.server.getServiceAuth?"
    assert url =~ "aud=did%3Aweb%3Aservice.test"
    assert url =~ "exp=1800000000"
    assert url =~ "lxm=app.bsky.feed.getTimeline"
    assert {"authorization", "Bearer token123"} in opts[:headers]
  end
end
