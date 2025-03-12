defmodule Lexicon.App.Bsky.Feed.GetPostsTest do
  use ProtoRune.DataCase
  
  alias Lexicon.App.Bsky.Feed.GetPosts

  describe "validate_params/1" do
    test "validates required fields" do
      # Missing uris
      assert {:error, changeset} = GetPosts.validate_params(%{})
      assert "can't be blank" in errors_on(changeset).uris
    end

    test "validates uris format" do
      # Valid URIs
      assert {:ok, params} = GetPosts.validate_params(%{
        uris: ["at://did:plc:1234/post/1", "at://did:plc:5678/post/2"]
      })
      assert length(params.uris) == 2

      # Invalid URI format
      assert {:error, changeset} = GetPosts.validate_params(%{
        uris: ["at://did:plc:1234/post/1", "invalid-uri"]
      })
      assert "must all be AT URIs" in errors_on(changeset).uris
    end

    test "validates uris count" do
      # Valid number of URIs
      assert {:ok, _} = GetPosts.validate_params(%{
        uris: ["at://did:plc:1234/post/1"]
      })

      # Too many URIs
      many_uris = for i <- 1..26, do: "at://did:plc:1234/post/#{i}"
      assert {:error, changeset} = GetPosts.validate_params(%{
        uris: many_uris
      })
      assert "should have at most 25 item(s)" in errors_on(changeset).uris

      # Empty uris
      assert {:error, changeset} = GetPosts.validate_params(%{
        uris: []
      })
      assert "should have at least 1 item(s)" in errors_on(changeset).uris
    end
  end

  describe "validate_output/1" do
    test "validates required fields" do
      # Missing posts
      assert {:error, changeset} = GetPosts.validate_output(%{})
      assert "can't be blank" in errors_on(changeset).posts

      # With empty posts
      assert {:ok, output} = GetPosts.validate_output(%{
        posts: []
      })
      assert output.posts == []
    end

    test "accepts post items" do
      post = %{
        uri: "at://did:plc:1234/post/1",
        cid: "bafyrei...",
        author: %{did: "did:plc:1234", handle: "test.bsky.app"},
        record: %{text: "Hello world", createdAt: "2023-01-01T00:00:00Z"},
        indexedAt: "2023-01-01T00:00:01Z"
      }
      
      assert {:ok, output} = GetPosts.validate_output(%{
        posts: [post, post]
      })
      assert length(output.posts) == 2
    end
  end
end