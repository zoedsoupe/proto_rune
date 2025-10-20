defmodule ProtoRune.XRPC.QueryTest do
  use ExUnit.Case, async: true

  alias ProtoRune.XRPC.Query

  describe "new/1" do
    test "creates a query with method only" do
      query = Query.new("app.bsky.actor.getProfile")

      assert query.method == "app.bsky.actor.getProfile"
      assert query.params == %{}
      assert query.headers == %{}
      assert query.parser == nil
      assert query.base_url == nil
    end
  end

  describe "new/2" do
    test "creates a query with parser" do
      parser = %{name: :string}
      query = Query.new("app.bsky.actor.getProfile", from: parser)

      assert query.method == "app.bsky.actor.getProfile"
      assert query.parser == parser
      assert query.base_url == nil
    end

    test "creates a query with base_url" do
      query = Query.new("app.bsky.actor.getProfile", base_url: "https://custom.pds")

      assert query.method == "app.bsky.actor.getProfile"
      assert query.base_url == "https://custom.pds"
    end

    test "creates a query with both parser and base_url" do
      parser = %{name: :string}
      query = Query.new("app.bsky.actor.getProfile", from: parser, base_url: "https://custom.pds")

      assert query.parser == parser
      assert query.base_url == "https://custom.pds"
    end
  end

  describe "put_param/3" do
    test "adds a parameter to the query" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new()
        |> Query.put_param(:actor, "alice.bsky.social")

      assert query.params[:actor] == "alice.bsky.social"
    end

    test "updates an existing parameter" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new()
        |> Query.put_param(:actor, "alice.bsky.social")
        |> Query.put_param(:actor, "bob.bsky.social")

      assert query.params[:actor] == "bob.bsky.social"
    end
  end

  describe "put_header/3" do
    test "adds a header to the query" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new()
        |> Query.put_header(:authorization, "Bearer token123")

      assert query.headers[:authorization] == "Bearer token123"
    end

    test "updates an existing header" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new()
        |> Query.put_header(:authorization, "Bearer token123")
        |> Query.put_header(:authorization, "Bearer new_token")

      assert query.headers[:authorization] == "Bearer new_token"
    end
  end

  describe "put_base_url/2" do
    test "sets the base_url" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new()
        |> Query.put_base_url("https://custom.pds")

      assert query.base_url == "https://custom.pds"
    end

    test "updates existing base_url" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new(base_url: "https://old.pds")
        |> Query.put_base_url("https://new.pds")

      assert query.base_url == "https://new.pds"
    end
  end

  describe "add_params/2" do
    test "validates and adds params with valid data" do
      parser = %{actor: {:required, :string}, limit: :integer}

      query = Query.new("app.bsky.actor.getProfile", from: parser)

      assert {:ok, updated_query} = Query.add_params(query, %{actor: "alice.bsky.social", limit: 50})
      assert updated_query.params.actor == "alice.bsky.social"
      assert updated_query.params.limit == 50
    end

    test "returns error with invalid data" do
      parser = %{actor: {:required, :string}}

      query = Query.new("app.bsky.actor.getProfile", from: parser)

      assert {:error, _reason} = Query.add_params(query, %{})
    end
  end

  describe "String.Chars protocol" do
    test "converts query to URL string without params" do
      query = Query.new("app.bsky.actor.getProfile", base_url: "https://bsky.social/xrpc")

      url = to_string(query)

      assert url == "https://bsky.social/xrpc/app.bsky.actor.getProfile"
    end

    test "converts query to URL string with params" do
      query =
        "app.bsky.actor.getProfile"
        |> Query.new(base_url: "https://bsky.social/xrpc")
        |> Query.put_param(:actor, "alice.bsky.social")
        |> Query.put_param(:limit, 50)

      url = to_string(query)

      assert url =~ "https://bsky.social/xrpc/app.bsky.actor.getProfile?"
      assert url =~ "actor=alice.bsky.social"
      assert url =~ "limit=50"
    end

    test "uses default when base_url is nil" do
      query = Query.new("app.bsky.actor.getProfile")

      url = to_string(query)

      # Should use Config fallback - verify structure rather than exact value
      assert url =~ ~r|^https?://.*xrpc/app\.bsky\.actor\.getProfile$|
    end

    test "URL encodes param values" do
      query =
        "app.bsky.feed.searchPosts"
        |> Query.new(base_url: "https://bsky.social/xrpc")
        |> Query.put_param(:q, "hello world")

      url = to_string(query)

      assert url =~ "q=hello+world"
    end
  end
end
