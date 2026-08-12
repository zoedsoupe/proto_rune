defmodule ProtoRune.LoginTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Session

  defmodule CaptureAdapter do
    @moduledoc false
    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, _opts) do
      send(Process.whereis(:capture_adapter_test), {method, url})

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
    end
  end

  setup do
    previous = Application.get_env(:proto_rune, :http_client)
    on_exit(fn -> restore_env(:http_client, previous) end)

    Application.put_env(:proto_rune, :http_client, CaptureAdapter)
    Application.put_env(:proto_rune, :rate_limit, false)
    on_exit(fn -> Application.delete_env(:proto_rune, :rate_limit) end)

    Process.register(self(), :capture_adapter_test)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:proto_rune, key)
  defp restore_env(key, value), do: Application.put_env(:proto_rune, key, value)

  describe "login/3" do
    test "createSession defaults to bsky.social" do
      assert {:ok, %Session{}} = ProtoRune.login("alice.bsky.social", "app-password")

      assert_received {:post, "https://bsky.social/xrpc/com.atproto.server.createSession"}
    end

    test ":service opt targets the createSession call itself, normalized with /xrpc" do
      assert {:ok, %Session{} = session} =
               ProtoRune.login("alice.bsky.social", "app-password", service: "https://pds.example.com")

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
