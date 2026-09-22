defmodule ProtoRune.Atproto.Identity.HandleResolverTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Atproto.Identity.HandleResolver

  setup do
    http =
      fake_http(fn :get, _url, _opts ->
        {:ok,
         %{
           status: 200,
           # Req-style headers: values are lists
           headers: %{"content-type" => ["text/plain; charset=utf-8"]},
           body: "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
         }}
      end)

    {:ok, http: http}
  end

  test "resolve_https/2 accepts list-valued content-type headers", %{http: http} do
    assert {:ok, "did:plc:ewvi7nxzyoun6zhxrhs64oiz"} =
             HandleResolver.resolve_https("example.com", retry_count: 0, http: http)
  end
end
