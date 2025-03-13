defmodule Lexicon.App.Bsky.Feed.GetTimelineTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Feed.GetTimeline

  describe "validate_params/1" do
    test "accepts empty parameters" do
      assert {:ok, params} = GetTimeline.validate_params(%{})
      assert params == %{}
    end

    test "validates limit constraints" do
      # Valid limit
      assert {:ok, params} = GetTimeline.validate_params(%{limit: 50})
      assert params.limit == 50

      # Invalid limit (too small)
      assert {:error, changeset} = GetTimeline.validate_params(%{limit: 0})
      assert "must be greater than 0" in errors_on(changeset).limit

      # Invalid limit (too large)
      assert {:error, changeset} = GetTimeline.validate_params(%{limit: 101})
      assert "must be less than or equal to 100" in errors_on(changeset).limit
    end

    test "accepts optional parameters" do
      # With algorithm and cursor
      assert {:ok, params} =
               GetTimeline.validate_params(%{
                 algorithm: "reverse-chronological",
                 limit: 20,
                 cursor: "abc123"
               })

      assert params.algorithm == "reverse-chronological"
      assert params.limit == 20
      assert params.cursor == "abc123"
    end
  end

  describe "validate_output/1" do
    test "validates required fields" do
      # Missing feed
      assert {:error, changeset} =
               GetTimeline.validate_output(%{
                 cursor: "xyz789"
               })

      assert "can't be blank" in errors_on(changeset).feed

      # With required fields
      assert {:ok, output} =
               GetTimeline.validate_output(%{
                 feed: [],
                 cursor: "xyz789"
               })

      assert output.feed == []
      assert output.cursor == "xyz789"
    end

    test "accepts feed items" do
      feed_item = %{
        post: %{
          uri: "at://did:plc:1234/post/1",
          cid: "bafyrei...",
          author: %{did: "did:plc:1234", handle: "test.bsky.app"},
          record: %{text: "Hello world", createdAt: "2023-01-01T00:00:00Z"},
          indexedAt: "2023-01-01T00:00:01Z"
        }
      }

      assert {:ok, output} =
               GetTimeline.validate_output(%{
                 feed: [feed_item],
                 cursor: "xyz789"
               })

      assert length(output.feed) == 1
    end
  end
end
