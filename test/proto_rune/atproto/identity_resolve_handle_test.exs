defmodule ProtoRune.Atproto.IdentityResolveHandleXRPCTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Identity

  defp stub(test_pid, response) do
    fake_http(fn method, url, opts ->
      send(test_pid, {:request, method, url, opts})
      {:ok, response}
    end)
  end

  describe "resolve_handle/2 via com.atproto.identity.resolveHandle" do
    test "resolves a handle against the given PDS" do
      http = stub(self(), %{status: 200, body: JSON.encode!(%{"did" => "did:plc:abc123"})})

      assert {:ok, "did:plc:abc123"} = Identity.resolve_handle("https://pds.test", "alice.test", http: http)

      assert_received {:request, :get, url, _opts}
      assert url == "https://pds.test/xrpc/com.atproto.identity.resolveHandle?handle=alice.test"
    end

    test "falls back to the default base URL when no PDS is given" do
      http = stub(self(), %{status: 200, body: JSON.encode!(%{"did" => "did:plc:abc123"})})

      assert {:ok, "did:plc:abc123"} = Identity.resolve_handle(nil, "alice.test", http: http)

      assert_received {:request, :get, url, _opts}
      assert url == "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=alice.test"
    end

    test "rejects malformed handles without hitting the wire" do
      assert {:error, :invalid_format} = Identity.resolve_handle("https://pds.test", "not a handle")
    end
  end
end
