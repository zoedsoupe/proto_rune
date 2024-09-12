defmodule Bsky.Schema do
  @moduledoc false

  use XRPC.DSL

  @doc """
  Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-preferences
  """
  defquery("app.bsky.actor.getPreferences")

  @doc """
  Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-profile
  """
  defquery "app.bsky.actor.getProfile" do
    param(:actor, {:required, :string})
  end

  @doc """
  Get detailed profile views of multiple actors.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-profiles
  """
  defquery "app.bsky.actor.getProfiles" do
    param(:actors, {:required, {:list, :string}})
  end

  @doc """
  Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-suggestions
  """
  defquery "app.bsky.actor.getSuggestions" do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Set the private preferences attached to the account.

  https://docs.bsky.app/docs/api/app-bsky-actor-put-preferences
  """
  defprocedure "app.bsky.actor.putPreferences" do
    # implementar schemas
    param(:preferences, {:required, :map})
  end

  @doc """
  Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-search-actors-typeahead
  """
  defquery "app.bsky.actor.searchActorsTypeahead" do
    param(:q, :string)
    param(:limit, :integer)
  end

  @doc """
  Find actors (profiles) matching search criteria. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-search-actors
  """
  defquery "app.bsky.actor.searchActors" do
    param(:q, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).

  https://docs.bsky.app/docs/api/app-bsky-feed-describe-feed-generator
  """
  defquery("app.bsky.feed.describeFeedGenerator")

  @doc """
  Get a list of feeds (feed generator records) created by the actor (in the actor's repo).

  https://docs.bsky.app/docs/api/app-bsky-feed-get-actor-feeds
  """
  defquery "app.bsky.feed.getActorFeeds" do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-actor-likes
  """
  defquery "app.bsky.feed.getActorLikes" do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-author-feed
  """
  defquery "app.bsky.feed.getAuthorFeed" do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)

    param(
      :filter,
      {:enum,
       [:posts_with_replies, :posts_no_replies, :posts_with_media, :posts_and_author_threads]}
    )
  end

  @doc """
  Get information about a feed generator. Implemented by AppView.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-generator
  """
  defquery "app.bsky.feed.getFeedGenerator" do
    param(:feed, {:required, :string})
  end

  @doc """
  Get information about a list of feed generators.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-generators
  """
  defquery "app.bsky.feed.getFeedGenerators" do
    param(:feed, {:required, {:list, :string}})
  end

  @doc """
  Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-skeleton
  """
  defquery "app.bsky.feed.getFeedSkeleton" do
    param(:feed, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a hydrated feed from an actor's selected feed generator. Implemented by App View.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed
  """
  defquery "app.bsky.feed.getFeed" do
    param(:feed, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get like records which reference a subject (by AT-URI and CID).

  https://docs.bsky.app/docs/api/app-bsky-feed-get-likes
  """
  defquery "app.bsky.feed.getLikes" do
    param(:uri, {:required, :string})
    param(:cid, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  defprocedure "app.bsky.graph.muteActor" do
    param(:actor, {:required, :string})
  end
end
