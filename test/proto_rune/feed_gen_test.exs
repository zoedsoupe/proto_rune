defmodule ProtoRune.Bsky.FeedGenTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Bsky.FeedGen

  describe "skeleton/2" do
    test "wraps bare URIs and keeps map items as-is" do
      assert FeedGen.skeleton(
               [
                 "at://did:plc:a/app.bsky.feed.post/1",
                 %{post: "at://did:plc:a/app.bsky.feed.post/2", feed_context: "ctx"}
               ],
               "cursor2"
             ) == %{
               feed: [
                 %{post: "at://did:plc:a/app.bsky.feed.post/1"},
                 %{post: "at://did:plc:a/app.bsky.feed.post/2", feed_context: "ctx"}
               ],
               cursor: "cursor2"
             }
    end

    test "cursor defaults to nil" do
      assert FeedGen.skeleton([]) == %{feed: [], cursor: nil}
    end
  end

  describe "describe/2" do
    test "advertises the service did and feed uris" do
      assert FeedGen.describe("did:web:feeds.example.com", ["at://did:plc:a/app.bsky.feed.generator/elixir"]) ==
               %{
                 did: "did:web:feeds.example.com",
                 feeds: [%{uri: "at://did:plc:a/app.bsky.feed.generator/elixir"}]
               }
    end
  end

  describe "generator_record/2" do
    test "builds the minimal record" do
      record = FeedGen.generator_record("did:web:feeds.example.com", display_name: "Elixir")

      assert record[:"$type"] == "app.bsky.feed.generator"
      assert record[:did] == "did:web:feeds.example.com"
      assert record[:display_name] == "Elixir"
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(record[:created_at])
      refute Map.has_key?(record, :description)
    end

    test "includes optional fields when given" do
      record =
        FeedGen.generator_record("did:web:feeds.example.com",
          display_name: "Elixir",
          description: "All things Elixir",
          accepts_interactions: true
        )

      assert record[:description] == "All things Elixir"
      assert record[:accepts_interactions] == true
    end

    test "requires a display name" do
      assert_raise ArgumentError, fn -> FeedGen.generator_record("did:web:x", []) end
    end
  end
end
