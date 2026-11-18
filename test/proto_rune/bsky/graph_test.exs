defmodule ProtoRune.Bsky.GraphTest do
  use ProtoRune.TestCase, async: true

  alias ProtoRune.Bsky.Graph

  test "get_relationships uses the corrected XRPC method and URL" do
    http =
      fake_http(fn method, url, _opts ->
        send(self(), {:request, method, url})
        {:ok, %{status: 200, body: %{}}}
      end)

    assert {:ok, %{}} =
             Graph.get_relationships(
               %{actor: "alice.test", others: ["bob.test", "carol.test"]},
               http: http
             )

    assert_received {:request, :get, url}
    assert url =~ "/app.bsky.graph.getRelationships?"
    assert url =~ "actor=alice.test"
    assert url =~ "others=bob.test&others=carol.test"
    refute url =~ "getRelationShips"
  end
end
