defmodule ProtoRune.Firehose.EventTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Firehose.Event

  doctest Event

  describe "collection?/2" do
    test "matches the exact collection" do
      event = %Event{type: :commit, ops: [%{action: :create, path: "app.bsky.feed.post/abc", cid: nil}]}
      assert Event.collection?(event, "app.bsky.feed.post")
    end

    test "matches when any operation matches" do
      event = %Event{
        type: :commit,
        ops: [
          %{action: :create, path: "com.example.thing/abc", cid: nil},
          %{action: :delete, path: "app.bsky.feed.like/xyz", cid: nil}
        ]
      }

      assert Event.collection?(event, "app.bsky.feed")
      refute Event.collection?(event, "app.bsky.graph")
    end

    test "does not match a different namespace sharing a prefix" do
      event = %Event{type: :commit, ops: [%{action: :create, path: "app.bsky.feedback.x/abc", cid: nil}]}
      refute Event.collection?(event, "app.bsky.feed")
    end

    test "returns false for non-commit events" do
      refute Event.collection?(%Event{type: :identity}, "app.bsky.feed")
      refute Event.collection?(%Event{type: :tombstone}, "app.bsky.feed")
    end
  end
end
