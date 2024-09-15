defmodule ProtoRune.Bsky.Feed do
  @moduledoc false

  import ProtoRune.XRPC.DSL

  @doc """
  Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).

  https://docs.bsky.app/docs/api/app-bsky-feed-describe-feed-generator
  """
  defquery "app.bsky.feed.describeFeedGenerator", for: :feed

  @doc """
  Get a list of feeds (feed generator records) created by the actor (in the actor's repo).

  https://docs.bsky.app/docs/api/app-bsky-feed-get-actor-feeds
  """
  defquery "app.bsky.feed.getActorFeeds", for: :feed do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-actor-likes
  """
  defquery "app.bsky.feed.getActorLikes", authenticated: true do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-author-feed
  """
  defquery "app.bsky.feed.getAuthorFeed", for: :feed do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string

    param :filter,
          {:enum,
           [:posts_with_replies, :posts_no_replies, :posts_with_media, :posts_and_author_threads]}
  end

  @doc """
  Get information about a feed generator. Implemented by AppView.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-generator
  """
  defquery "app.bsky.feed.getFeedGenerator", for: :feed do
    param :feed, {:required, :string}
  end

  @doc """
  Get information about a list of feed generators.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-generators
  """
  defquery "app.bsky.feed.getFeedGenerators", for: :feed do
    param :feed, {:required, {:list, :string}}
  end

  @doc """
  Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-skeleton
  """
  defquery "app.bsky.feed.getFeedSkeleton", for: :feed do
    param :feed, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a hydrated feed from an actor's selected feed generator. Implemented by App View.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed
  """
  defquery "app.bsky.feed.getFeed", for: :feed do
    param :feed, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get like records which reference a subject (by AT-URI and CID).

  https://docs.bsky.app/docs/api/app-bsky-feed-get-likes
  """
  defquery "app.bsky.feed.getLikes", for: :like do
    param :uri, {:required, :string}
    param :cid, :string
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-list-feed
  """
  defquery "app.bsky.feed.getListFeed", for: :feed do
    param :list, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-post-thread
  """
  defquery "app.bsky.feed.getPostThread", for: :thread do
    param :uri, {:required, :string}
    param :depth, :integer
    param :parent_height, :integer
  end

  defquery "app.bsky.feed.getPostThread", authenticated: true do
    param :uri, {:required, :string}
    param :depth, :integer
    param :parent_height, :integer
  end

  @doc """
  Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-posts
  """
  defquery "app.bsky.feed.getPosts", for: :post do
    param :uris, {:required, {:list, :string}}
  end

  @doc """
  Get a list of quotes for a given post.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-quotes
  """
  defquery "app.bsky.feed.getQuotes", for: :quote do
    param :uri, {:required, :string}
    param :cid, :string
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a list of reposts for a given post.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-reposted-by
  """
  defquery "app.bsky.feed.getRepostedBy", for: :repost do
    param :uri, {:required, :string}
    param :cid, :string
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a list of suggested feeds (feed generators) for the requesting account.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-suggested-feeds
  """
  defquery "app.bsky.feed.getSuggestedFeeds", authenticated: true

  defquery "app.bsky.feed.getSuggestedFeeds", authenticated: true do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-timeline
  """
  defquery "app.bsky.feed.getTimeline", authenticated: true

  defquery "app.bsky.feed.getTimeline", authenticated: true do
    param :algorithm, :string
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Find posts matching search criteria, returning views of those posts.

  https://docs.bsky.app/docs/api/app-bsky-feed-search-posts
  """
  defquery "app.bsky.feed.searchPosts", for: :search do
    param :q, {:required, :string}
    param :sort, {:enum, [:top, :latest]}
    param :since, :date
    param :until, :date
    param :mentions, {:list, :string}
    param :author, :string
    param :lang, :string
    param :domain, :string
    param :url, :string
    param :tag, {:list, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @literal_interactions [:seen, :like, :repost, :reply, :quote, :share]

  @interaction %{
    item: :string,
    feed_context: :string,
    event: {:custom, {__MODULE__, :parse_event}}
  }

  @doc """
  Send information about interactions with feed items back to the feed generator that served them.

  https://docs.bsky.app/docs/api/app-bsky-feed-send-interactions
  """
  defprocedure "app.sbky.feed.sendInterations", authenticated: true do
    param :interactions, {:required, {:list, @interaction}}
  end

  def parse_event(event) when is_atom(event) do
    schema =
      {:enum,
       [
         :request_less,
         :request_more,
         :click_through_item,
         :click_through_author,
         :click_through_reposter,
         :click_through_embed,
         :seen,
         :like,
         :repost,
         :reply,
         :quote,
         :share
       ]}

    with {:ok, _} <- Peri.validate(schema, event) do
      event
      |> Kernel.in(@literal_interactions)
      |> if(do: "interaction#{Macro.camelize(event)}", else: event)
      |> then(&"app.bsky.feed.defs##{Macro.camelize(&1)}")
    end
  end

  def parse_event(string) when is_binary(string) do
    {:error, "need to be an atom", []}
  end
end
