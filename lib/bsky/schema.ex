defmodule Bsky.Schema do
  @moduledoc false

  use XRPC.DSL

  import Peri

  @doc """
  Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-preferences
  """
  defquery("app.bsky.actor.getPreferences", for: :preferences, authenticated: true)

  @doc """
  Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-profile
  """
  defquery "app.bsky.actor.getProfile", for: :profile do
    param(:actor, {:required, :string})
  end

  defquery "app.bsky.actor.getProfile", authenticated: true do
    param(:actor, {:required, :string})
  end

  @doc """
  Get detailed profile views of multiple actors.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-profiles
  """
  defquery "app.bsky.actor.getProfiles", for: :profile do
    param(:actors, {:required, {:list, :string}})
  end

  defquery "app.bsky.actor.getProfiles", authenticated: true do
    param(:actors, {:required, {:list, :string}})
  end

  @doc """
  Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-suggestions
  """
  defquery "app.bsky.actor.getSuggestions", authenticated: true do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Set the private preferences attached to the account.

  https://docs.bsky.app/docs/api/app-bsky-actor-put-preferences
  """
  defprocedure "app.bsky.actor.putPreferences", authenticated: true do
    # implementar schemas
    param(:preferences, {:required, :map})
  end

  @doc """
  Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-search-actors-typeahead
  """
  defquery "app.bsky.actor.searchActorsTypeahead", for: :search_actors do
    param(:q, :string)
    param(:limit, :integer)
  end

  @doc """
  Find actors (profiles) matching search criteria. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-search-actors
  """
  defquery "app.bsky.actor.searchActors", for: :search_actors do
    param(:q, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).

  https://docs.bsky.app/docs/api/app-bsky-feed-describe-feed-generator
  """
  defquery("app.bsky.feed.describeFeedGenerator", for: :feed)

  @doc """
  Get a list of feeds (feed generator records) created by the actor (in the actor's repo).

  https://docs.bsky.app/docs/api/app-bsky-feed-get-actor-feeds
  """
  defquery "app.bsky.feed.getActorFeeds", for: :feed do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-actor-likes
  """
  defquery "app.bsky.feed.getActorLikes", authenticated: true do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-author-feed
  """
  defquery "app.bsky.feed.getAuthorFeed", for: :feed do
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
  defquery "app.bsky.feed.getFeedGenerator", for: :feed do
    param(:feed, {:required, :string})
  end

  @doc """
  Get information about a list of feed generators.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-generators
  """
  defquery "app.bsky.feed.getFeedGenerators", for: :feed do
    param(:feed, {:required, {:list, :string}})
  end

  @doc """
  Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed-skeleton
  """
  defquery "app.bsky.feed.getFeedSkeleton", for: :feed do
    param(:feed, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a hydrated feed from an actor's selected feed generator. Implemented by App View.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-feed
  """
  defquery "app.bsky.feed.getFeed", for: :feed do
    param(:feed, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get like records which reference a subject (by AT-URI and CID).

  https://docs.bsky.app/docs/api/app-bsky-feed-get-likes
  """
  defquery "app.bsky.feed.getLikes", for: :like do
    param(:uri, {:required, :string})
    param(:cid, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-list-feed
  """
  defquery "app.bsky.feed.getListFeed", for: :feed do
    param(:list, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-post-thread
  """
  defquery "app.bsky.feed.getPostThread", for: :thread do
    param(:uri, {:required, :string})
    param(:depth, :integer)
    param(:parent_height, :integer)
  end

  defquery "app.bsky.feed.getPostThread", authenticated: true do
    param(:uri, {:required, :string})
    param(:depth, :integer)
    param(:parent_height, :integer)
  end

  @doc """
  Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-posts
  """
  defquery "app.bsky.feed.getPosts", for: :post do
    param(:uris, {:required, {:list, :string}})
  end

  @doc """
  Get a list of quotes for a given post.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-quotes
  """
  defquery "app.bsky.feed.getQuotes", for: :quote do
    param(:uri, {:required, :string})
    param(:cid, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a list of reposts for a given post.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-reposted-by
  """
  defquery "app.bsky.feed.getRepostedBy", for: :repost do
    param(:uri, {:required, :string})
    param(:cid, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a list of suggested feeds (feed generators) for the requesting account.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-suggested-feeds
  """
  defquery "app.bsky.feed.getSuggestedFeeds", authenticated: true do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.

  https://docs.bsky.app/docs/api/app-bsky-feed-get-timeline
  """
  defquery "app.bsky.feed.getTimeline", authenticated: true do
    param(:algorithm, :string)
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Find posts matching search criteria, returning views of those posts.

  https://docs.bsky.app/docs/api/app-bsky-feed-search-posts
  """
  defquery "app.bsky.feed.searchPosts", for: :search do
    param(:q, {:required, :string})
    param(:sort, {:enum, [:top, :latest]})
    param(:since, :date)
    param(:until, :date)
    param(:mentions, {:list, :string})
    param(:author, :string)
    param(:lang, :string)
    param(:domain, :string)
    param(:url, :string)
    param(:tag, {:list, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  defschema(
    :interaction_event_t,
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
  )

  @literal_interactions [:seen, :like, :repost, :reply, :quote, :share]

  defschema(:interaction, %{
    item: :string,
    feed_context: :string,
    event:
      {:custom,
       fn
         event when is_atom(event) ->
           schema = get_schema(:interaction_event_t)

           with {:ok, _} <- Peri.validate(schema, event) do
             event
             |> Kernel.in(@literal_interactions)
             |> if(do: "interaction#{Macro.camelize(event)}", else: event)
             |> then(&"app.bsky.feed.defs##{Macro.camelize(&1)}")
           end

         string when is_binary(string) ->
           {:error, "need to be an atom", []}
       end}
  })

  @doc """
  Send information about interactions with feed items back to the feed generator that served them.

  https://docs.bsky.app/docs/api/app-bsky-feed-send-interactions
  """
  defprocedure "app.sbky.feed.sendInterations", authenticated: true do
    param(:interactions, {:required, {:list, :interaction}})
  end

  @doc """
  Get a list of starter packs created by the actor.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-actor-starter-packs
  """
  defquery "app.bsky.graph.getActorStarterPacks", for: :actor do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates which accounts the requesting account is currently blocking. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-blocks
  """
  defquery "app.bsky.graph.getBlocks", authenticated: true do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates accounts which follow a specified account (actor).

  https://docs.bsky.app/docs/api/app-bsky-graph-get-followers
  """
  defquery "app.bsky.graph.getFollowers", for: :todo do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates accounts which a specified account (actor) follows.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-follows
  """
  defquery "app.bsky.graph.getFollows", for: :todo do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates accounts which follow a specified account (actor) and are followed by the viewer.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-known-followers
  """
  defquery "app.bsky.graph.getKnownFollowers", for: :todo do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Get mod lists that the requesting account (actor) is blocking. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-list-blocks
  """
  defquery "app.bsky.graph.getListBlocks", authenticated: true do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-list-mutes
  """
  defquery "app.bsky.graph.getListMutes", authenticated: true do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Gets a 'view' (with additional context) of a specified list.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-list
  """
  defquery "app.bsky.graph.getList", for: :Todo do
    param(:list, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates the lists created by a specified account (actor).

  https://docs.bsky.app/docs/api/app-bsky-graph-get-lists
  """
  defquery "app.bsky.graph.getLists", for: :Todo do
    param(:actor, {:required, :string})
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-mutes
  """
  defquery "app.bsky.graph.getMutes", for: :todo do
    param(:limit, :integer)
    param(:cursor, :string)
  end

  @doc """
  Enumerates public relationships between one account, and a list of other accounts. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-relationships
  """
  defquery "app.bsky.graph.getRelationShips", for: :todo do
    param(:actor, {:required, :string})
    param(:others, {:list, :string})
  end

  @doc """
  Gets a view of a starter pack.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-starter-pack
  """
  defquery "app.bsky.graph.getStarterPack", for: :todo do
    param(:starter_pack, {:required, :string})
  end

  @doc """
  Get views for a list of starter packs.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-starter-packs
  """
  defquery "app.bsky.graph.getStarterPacks", for: :todo do
    param(:uris, {:required, {:list, :string}})
  end

  @doc """
  Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-suggested-follows-by-actor
  """
  defquery "app.bsky.graph.getSuggestedFollowsByActor", for: :todo do
    param(:actor, {:required, :string})
  end

  @doc """
  Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-mute-actor-list
  """
  defprocedure "app.bsky.graph.muteActorList", authenticated: true do
    param(:list, {:required, :string})
  end

  @doc """
  Creates a mute relationship for the specified account. Mutes are private in Bluesky. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-mute-actor
  """
  defprocedure "app.bsky.graph.muteActor", authenticated: true do
    param(:actor, {:required, :string})
  end

  @doc """
  Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-mute-thread
  """
  defprocedure "app.bsky.graph.muteThread", authenticated: true do
    param(:root, {:required, :string})
  end

  @doc """
  Unmutes the specified list of accounts. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-unmute-actor-list
  """
  defprocedure "app.bsky.graph.unmuteActorList", authenticated: true do
    param(:list, {:required, :string})
  end

  @doc """
  Unmutes the specified account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-unmute-actor
  """
  defprocedure "app.bsky.graph.unmuteActor", authenticated: true do
    param(:actor, {:required, :string})
  end

  @doc """
  Unmutes the specified thread. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-unmute-thread
  """
  defprocedure "app.bsky.graph.unmuteThread", authenticated: true do
    param(:root, {:required, :string})
  end

  @doc """
  Get information about a list of labeler services.

  https://docs.bsky.app/docs/api/app-bsky-labeler-get-services
  """
  defquery "app.bsky.labeler.getServices", for: :todo do
    param(:dids, {:required, {:list, :string}})
    param(:detailed, :boolean)
  end

  @doc """
  Count the number of unread notifications for the requesting account. Requires auth.
  """
  defquery "app.bsky.notification.getUnreadCount", authenticated: true do
    param(:priority, :boolean)
    param(:seen_at, :datetime)
  end

  @doc """
  Enumerate notifications for the requesting account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-list-notifications
  """
  defquery "app.bsky.notification.listNotifications", authenticated: true do
    param(:limit, :integer)
    param(:priority, :boolean)
    param(:cursor, :string)
    param(:seen_at, :datetime)
  end

  @doc """
  Set notification-related preferences for an account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-put-preferences
  """
  defprocedure "app.bsky.notification.putPreferences", authenticated: true do
    param(:priority, {:required, :boolean})
  end

  @doc """
  Register to receive push notifications, via a specified service, for the requesting account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-register-push
  """
  defprocedure "app.bsky.notification.registerPush", authenticated: true do
    param(:service_did, {:required, :string})
    param(:token, {:required, :string})
    param(:platform, {:required, {:enum, [:ios, :android, :web]}})
    param(:app_id, {:required, :string})
  end

  @doc """
  Notify server that the requesting account has seen notifications. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-update-seen
  """
  defprocedure "app.bsky.notification.updateSeen", authenticated: true do
    param(:seen_at, {:required, :datetime})
  end

  @doc """
  Get status details for a video processing job.

  https://docs.bsky.app/docs/api/app-bsky-video-get-job-status
  """
  defquery "app.bsky.video.getJobStatus", for: :todo do
    param(:job_id, {:required, :string})
  end

  @doc """
  Get video upload limits for the authenticated user.

  https://docs.bsky.app/docs/api/app-bsky-video-get-upload-limits
  """
  defquery("app.bsky.video.getUploadLimits", authenticated: true)

  @doc """
  Upload a video to be processed then stored on the PDS.

  https://docs.bsky.app/docs/api/app-bsky-video-upload-video
  """
  defprocedure "app.bsky.video.uploadVideo", authenticated: true do
    # TODO
    param(:any, :any)
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-delete-account
  """
  defprocedure("chat.bsky.actor.deleteAccount", authenticated: true)
end
