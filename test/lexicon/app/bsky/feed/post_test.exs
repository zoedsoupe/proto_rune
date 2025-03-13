defmodule Lexicon.App.Bsky.Feed.PostTest do
  use ProtoRune.DataCase

  alias Lexicon.App.Bsky.Feed.Post

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Post.changeset(%Post{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).text
      assert "can't be blank" in errors_on(changeset).created_at
    end

    test "validates text length" do
      # Valid text
      valid_text = String.duplicate("x", 3000)

      changeset =
        Post.changeset(%Post{}, %{
          text: valid_text,
          created_at: DateTime.utc_now()
        })

      assert changeset.valid?

      # Invalid text (too long)
      long_text = String.duplicate("x", 3001)

      changeset =
        Post.changeset(%Post{}, %{
          text: long_text,
          created_at: DateTime.utc_now()
        })

      refute changeset.valid?
      assert "should be at most 3000 character(s)" in errors_on(changeset).text
    end

    test "validates langs length" do
      # Valid langs
      valid_attrs = %{
        text: "Hello world",
        langs: ["en", "fr", "es"],
        created_at: DateTime.utc_now()
      }

      changeset = Post.changeset(%Post{}, valid_attrs)
      assert changeset.valid?

      # Invalid langs (too many)
      invalid_attrs = %{
        text: "Hello world",
        langs: ["en", "fr", "es", "de"],
        created_at: DateTime.utc_now()
      }

      changeset = Post.changeset(%Post{}, invalid_attrs)
      refute changeset.valid?
      assert "should have at most 3 item(s)" in errors_on(changeset).langs
    end

    test "validates tags" do
      # Valid tags
      valid_attrs = %{
        text: "Hello world",
        tags: ["tag1", "tag2"],
        created_at: DateTime.utc_now()
      }

      changeset = Post.changeset(%Post{}, valid_attrs)
      assert changeset.valid?

      # Invalid tags (too many)
      many_tags = for i <- 1..9, do: "tag#{i}"

      invalid_attrs = %{
        text: "Hello world",
        tags: many_tags,
        created_at: DateTime.utc_now()
      }

      changeset = Post.changeset(%Post{}, invalid_attrs)
      refute changeset.valid?
      assert "should have at most 8 item(s)" in errors_on(changeset).tags

      # Invalid tags (too long)
      long_tag = String.duplicate("x", 641)

      invalid_attrs = %{
        text: "Hello world",
        tags: ["tag1", long_tag],
        created_at: DateTime.utc_now()
      }

      changeset = Post.changeset(%Post{}, invalid_attrs)
      refute changeset.valid?
      assert "tag should be at most 640 character(s)" in errors_on(changeset).tags
    end
  end

  describe "new/1" do
    test "creates a valid post" do
      assert {:ok, post} = Post.new(%{text: "Hello world"})
      assert post.text == "Hello world"
      assert %DateTime{} = post.created_at
    end

    test "creates a post with custom created_at" do
      created_at = DateTime.truncate(DateTime.utc_now(), :second)

      assert {:ok, post} =
               Post.new(%{
                 text: "Hello world",
                 created_at: created_at
               })

      assert post.text == "Hello world"
      assert post.created_at == created_at
    end

    test "returns error for invalid attributes" do
      assert {:error, changeset} = Post.new(%{})
      refute changeset.valid?
    end
  end

  describe "new!/1" do
    test "creates a valid post" do
      assert %Post{} = post = Post.new!(%{text: "Hello world"})
      assert post.text == "Hello world"
    end

    test "raises error for invalid attributes" do
      assert_raise RuntimeError, ~r/Invalid post/, fn ->
        Post.new!(%{})
      end
    end
  end
end
