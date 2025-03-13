defmodule Lexicon.App.Bsky.Unspecced.TrendingTopicTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Unspecced.TrendingTopic

  describe "changeset/2" do
    test "validates required fields" do
      changeset = TrendingTopic.changeset(%TrendingTopic{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).topic
      assert "can't be blank" in errors_on(changeset).link
    end

    test "accepts valid attributes with minimal fields" do
      changeset =
        TrendingTopic.changeset(%TrendingTopic{}, %{
          topic: "bluesky",
          link: "/search?q=bluesky"
        })

      assert changeset.valid?
    end

    test "accepts valid attributes with all fields" do
      changeset =
        TrendingTopic.changeset(%TrendingTopic{}, %{
          topic: "bluesky",
          display_name: "Bluesky",
          description: "Posts about Bluesky",
          link: "/search?q=bluesky"
        })

      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a valid trending topic with minimal fields" do
      attrs = %{
        topic: "bluesky",
        link: "/search?q=bluesky"
      }

      assert {:ok, topic} = TrendingTopic.new(attrs)
      assert topic.topic == attrs.topic
      assert topic.link == attrs.link
      assert topic.display_name == nil
      assert topic.description == nil
    end

    test "creates a valid trending topic with all fields" do
      attrs = %{
        topic: "bluesky",
        display_name: "Bluesky",
        description: "Posts about Bluesky",
        link: "/search?q=bluesky"
      }

      assert {:ok, topic} = TrendingTopic.new(attrs)
      assert topic.topic == attrs.topic
      assert topic.display_name == attrs.display_name
      assert topic.description == attrs.description
      assert topic.link == attrs.link
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = TrendingTopic.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid trending topic" do
      attrs = %{
        topic: "bluesky",
        link: "/search?q=bluesky"
      }

      assert %TrendingTopic{} = topic = TrendingTopic.new!(attrs)
      assert topic.topic == attrs.topic
      assert topic.link == attrs.link
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid trending topic/, fn ->
        TrendingTopic.new!(%{})
      end
    end
  end
end
