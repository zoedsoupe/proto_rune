defmodule ProtoRune.SessionManagerTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Session
  alias ProtoRune.SessionManager

  defp jwt(exp) do
    header = Base.url_encode64(JSON.encode!(%{"alg" => "ES256"}), padding: false)
    payload = Base.url_encode64(JSON.encode!(%{"exp" => exp}), padding: false)
    "#{header}.#{payload}.sig"
  end

  @exp 4_000_000_000

  describe "Session.parse/1" do
    test "extracts expires_at from the access JWT exp claim" do
      {:ok, session} =
        Session.parse(%{
          access_jwt: jwt(@exp),
          refresh_jwt: "refresh",
          did: "did:plc:test",
          handle: "alice.test"
        })

      assert session.expires_at == @exp
    end

    test "yields nil expires_at for a malformed token" do
      {:ok, session} =
        Session.parse(%{
          access_jwt: "not-a-jwt",
          refresh_jwt: "refresh",
          did: "did:plc:test",
          handle: "alice.test"
        })

      assert session.expires_at == nil
    end
  end

  describe "SessionManager" do
    test "refreshes the session through the session behaviour" do
      test_pid = self()

      http =
        fake_http(fn :post, url, _opts ->
          send(test_pid, {:refresh_request, url})

          {:ok,
           %{
             status: 200,
             body:
               JSON.encode!(%{
                 "accessJwt" => jwt(@exp),
                 "refreshJwt" => "new-refresh",
                 "did" => "did:plc:test",
                 "handle" => "alice.test"
               })
           }}
        end)

      session = %Session{
        access_jwt: jwt(@exp),
        refresh_jwt: "old-refresh",
        did: "did:plc:test",
        handle: "alice.test",
        service_url: "https://pds.test/xrpc"
      }

      {:ok, pid} = SessionManager.start_link(session: session, refresh_opts: [http: http], refresh_fraction: 0.0)

      assert_receive {:refresh_request, url}, 1_000
      assert url =~ "com.atproto.server.refreshSession"
      assert %Session{refresh_jwt: "new-refresh"} = SessionManager.session(pid)
    end

    test "stops with refresh_failed when the refresh errors" do
      Process.flag(:trap_exit, true)

      http =
        fake_http(fn :post, _url, _opts ->
          {:ok, %{status: 500, body: "{}"}}
        end)

      session = %Session{
        access_jwt: jwt(@exp),
        refresh_jwt: "old-refresh",
        did: "did:plc:test",
        handle: "alice.test",
        service_url: "https://pds.test/xrpc"
      }

      {:ok, pid} = SessionManager.start_link(session: session, refresh_opts: [http: http], refresh_fraction: 0.0)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, {:refresh_failed, _reason}}, 1_000
    end
  end
end
