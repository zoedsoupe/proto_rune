defmodule ProtoRune.LoginTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Session

  setup do
    test_pid = self()

    http =
      fake_http(fn method, url, _opts ->
        send(test_pid, {method, url})

        {:ok,
         %{
           status: 200,
           headers: %{},
           body: %{
             access_jwt: "access",
             refresh_jwt: "refresh",
             handle: "alice.bsky.social",
             did: "did:plc:alice"
           }
         }}
      end)

    {:ok, http: http}
  end

  describe "login/3" do
    test "createSession defaults to bsky.social", %{http: http} do
      assert {:ok, %Session{}} = ProtoRune.login("alice.bsky.social", "app-password", http: http)

      assert_received {:post, "https://bsky.social/xrpc/com.atproto.server.createSession"}
    end

    test ":service opt targets the createSession call itself, normalized with /xrpc", %{http: http} do
      assert {:ok, %Session{} = session} =
               ProtoRune.login("alice.bsky.social", "app-password",
                 service: "https://pds.example.com",
                 http: http
               )

      assert_received {:post, "https://pds.example.com/xrpc/com.atproto.server.createSession"}
      assert session.service_url == "https://pds.example.com/xrpc"
    end
  end

  describe "Session.normalize_service_url/1" do
    test "appends /xrpc to bare PDS endpoints" do
      assert Session.normalize_service_url("https://enoki.us-east.host.bsky.network") ==
               "https://enoki.us-east.host.bsky.network/xrpc"
    end

    test "keeps URLs that already end in /xrpc" do
      assert Session.normalize_service_url("https://bsky.social/xrpc") ==
               "https://bsky.social/xrpc"
    end

    test "trims trailing slashes" do
      assert Session.normalize_service_url("https://bsky.social/") ==
               "https://bsky.social/xrpc"
    end
  end

  describe "Session.parse/1" do
    test "normalizes the PDS endpoint from the DID document" do
      data = %{
        access_jwt: "access",
        refresh_jwt: "refresh",
        handle: "alice.bsky.social",
        did: "did:plc:alice",
        did_doc: %{
          service: [
            %{
              id: "#atproto_pds",
              type: "AtprotoPersonalDataServer",
              service_endpoint: "https://enoki.us-east.host.bsky.network"
            }
          ]
        }
      }

      assert {:ok, %Session{service_url: url}} = Session.parse(data)
      assert url == "https://enoki.us-east.host.bsky.network/xrpc"
    end
  end
end
