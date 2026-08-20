defmodule ProtoRune.Atproto.Identity.HandleResolverTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Atproto.Identity.HandleResolver

  defmodule FakeAdapter do
    @behaviour ProtoRune.HTTPClient.Adapter

    @impl true
    def request(:get, _url, _opts) do
      {:ok,
       %{
         status: 200,
         # Req-style headers: values are lists
         headers: %{"content-type" => ["text/plain; charset=utf-8"]},
         body: "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
       }}
    end
  end

  setup do
    Application.put_env(:proto_rune, :http_client, FakeAdapter)
    on_exit(fn -> Application.delete_env(:proto_rune, :http_client) end)
  end

  test "resolve_https/2 accepts list-valued content-type headers" do
    assert {:ok, "did:plc:ewvi7nxzyoun6zhxrhs64oiz"} =
             HandleResolver.resolve_https("example.com", retry_count: 0)
  end
end
