defmodule ProtoRune.Atproto.IdentityResolveHandleXRPCTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Identity

  defmodule HTTPStub do
    @moduledoc false

    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(method, url, opts) do
      handler = Application.fetch_env!(:proto_rune, :http_stub_handler)
      handler.(method, url, opts)
    end
  end

  setup do
    Application.put_env(:proto_rune, :http_client, HTTPStub)

    on_exit(fn ->
      Application.delete_env(:proto_rune, :http_client)
      Application.delete_env(:proto_rune, :http_stub_handler)
    end)

    :ok
  end

  defp stub(test_pid, response) do
    Application.put_env(:proto_rune, :http_stub_handler, fn method, url, opts ->
      send(test_pid, {:request, method, url, opts})
      {:ok, response}
    end)
  end

  describe "resolve_handle/2 via com.atproto.identity.resolveHandle" do
    test "resolves a handle against the given PDS" do
      stub(self(), %{status: 200, body: JSON.encode!(%{"did" => "did:plc:abc123"})})

      assert {:ok, "did:plc:abc123"} = Identity.resolve_handle("https://pds.test", "alice.test")

      assert_received {:request, :get, url, _opts}
      assert url == "https://pds.test/xrpc/com.atproto.identity.resolveHandle?handle=alice.test"
    end

    test "falls back to the default base URL when no PDS is given" do
      stub(self(), %{status: 200, body: JSON.encode!(%{"did" => "did:plc:abc123"})})

      assert {:ok, "did:plc:abc123"} = Identity.resolve_handle(nil, "alice.test")

      assert_received {:request, :get, url, _opts}
      assert url == "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=alice.test"
    end

    test "rejects malformed handles without hitting the wire" do
      assert {:error, :invalid_format} = Identity.resolve_handle("https://pds.test", "not a handle")
    end
  end
end
