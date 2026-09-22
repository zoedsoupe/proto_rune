defmodule ProtoRune.Bsky do
  @moduledoc """
  High-level Bluesky API helpers.

  Provides ergonomic wrappers around repository operations and XRPC calls
  for common Bluesky tasks. This module covers the most common verbs; the
  full generated endpoint coverage lives in the `ProtoRune.Bsky.*`
  modules (`ProtoRune.Bsky.Feed`, `ProtoRune.Bsky.Actor`,
  `ProtoRune.Bsky.Graph`, `ProtoRune.Bsky.Notification`,
  `ProtoRune.Bsky.Chat`, ...), which are public and called as
  `Module.endpoint(session, %{param: value})`.

  ## Examples

      # Post
      {:ok, post} = Bsky.post(session, "Hello!")

      # Like
      {:ok, like} = Bsky.like(session, post_uri, post_cid)

      # Follow
      {:ok, follow} = Bsky.follow(session, "alice.bsky.social")

      # Get profile
      {:ok, profile} = Bsky.get_profile(session, "bob.bsky.social")

      # Endpoint without a helper: call the generated module directly
      {:ok, feed} = ProtoRune.Bsky.Feed.get_author_feed(session, %{actor: "bob.bsky.social"})
  """

  alias ProtoRune.Atproto.Identity
  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Bsky.Actor
  alias ProtoRune.Bsky.Embed
  alias ProtoRune.Bsky.Feed
  alias ProtoRune.Bsky.FeedGen
  alias ProtoRune.Bsky.Graph
  alias ProtoRune.Bsky.Notification
  alias ProtoRune.Session
  alias ProtoRune.XRPC.Error

  @type session :: Session.t()

  @doc """
  Posts a text message to Bluesky.

  Supports both plain text strings and RichText structs with facets.

  ## Options

  - `:langs` - List of language codes (omitted when not given)
  - `:reply_to` - AT-URI of post to reply to
  - `:created_at` - Timestamp (default: now)
  - `:embed` - An embed map built with `ProtoRune.Bsky.Embed`
  - `:images` - A list of `{data, content_type, alt}` tuples (1 to 4). The
    images are uploaded as blobs and attached as an
    `app.bsky.embed.images` embed. When `:embed` is a quote
    (`Embed.record/2`), the result is a `recordWithMedia` embed.

  ## Examples

      # Simple text post
      {:ok, post} = Bsky.post(session, "Hello Bluesky!")

      # Reply to a post
      {:ok, reply} = Bsky.post(session, "Great point!",
        reply_to: "at://did:plc:xyz/app.bsky.feed.post/3k..."
      )

      # Post with images
      {:ok, post} = Bsky.post(session, "cat tax",
        images: [{File.read!("cat.png"), "image/png", "a cat"}]
      )

      # Quote post
      {:ok, post} = Bsky.post(session, "this!",
        embed: Bsky.Embed.record(quoted_uri, quoted_cid)
      )

      # Link card
      {:ok, post} = Bsky.post(session, "read this",
        embed: Bsky.Embed.external(url, "Title", "Description")
      )

      # Rich text with mentions and links
      alias ProtoRune.RichText

      {:ok, rt} =
        RichText.new()
        |> RichText.text("Hello ")
        |> RichText.mention("alice.bsky.social")
        |> RichText.text("!")
        |> RichText.build()

      {:ok, post} = Bsky.post(session, rt)
  """
  @spec post(session(), String.t() | map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(session, text, opts \\ [])

  def post(session, text, opts) when is_binary(text) do
    build_post(session, %{text: text}, opts)
  end

  def post(session, %{text: text, facets: facets}, opts) when is_binary(text) and is_list(facets) do
    build_post(session, %{text: text, facets: facets}, opts)
  end

  defp build_post(session, base, opts) do
    record =
      %{"$type": "app.bsky.feed.post", created_at: format_created_at(opts)}
      |> maybe_put(:langs, Keyword.get(opts, :langs))
      |> Map.merge(base)

    with {:ok, record} <- maybe_put_reply(session, record, opts),
         {:ok, record} <- maybe_put_embed(session, record, opts) do
      Repo.create_record(session, %{
        repo: Session.did(session),
        collection: "app.bsky.feed.post",
        record: record
      })
    end
  end

  defp format_created_at(opts) do
    opts |> Keyword.get(:created_at, DateTime.utc_now()) |> DateTime.to_iso8601()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_embed(session, record, opts) do
    with {:ok, media} <- maybe_images_embed(session, Keyword.get(opts, :images)) do
      case {Keyword.get(opts, :embed), media} do
        {nil, nil} ->
          {:ok, record}

        {embed, nil} ->
          {:ok, Map.put(record, :embed, embed)}

        {nil, media} ->
          {:ok, Map.put(record, :embed, media)}

        {%{:"$type" => "app.bsky.embed.record"} = quote, media} ->
          {:ok, Map.put(record, :embed, Embed.record_with_media(quote, media))}

        {_embed, _media} ->
          {:error, :conflicting_embeds}
      end
    end
  end

  defp maybe_images_embed(_session, nil), do: {:ok, nil}

  defp maybe_images_embed(session, images) when is_list(images) do
    images
    |> Enum.reduce_while({:ok, []}, fn {data, content_type, alt}, {:ok, acc} ->
      case Repo.upload_blob(session, data, content_type) do
        {:ok, %{blob: blob}} -> {:cont, {:ok, [%{alt: alt, image: blob} | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, uploaded} -> {:ok, Embed.images(Enum.reverse(uploaded))}
      {:error, _} = error -> error
    end
  end

  @doc """
  Likes a post.

  ## Examples

      {:ok, like} = Bsky.like(session, post.uri, post.cid)
  """
  @spec like(session(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def like(session, uri, cid) when is_binary(uri) and is_binary(cid) do
    record = %{
      "$type": "app.bsky.feed.like",
      subject: %{uri: uri, cid: cid},
      created_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Repo.create_record(session, %{
      repo: Session.did(session),
      collection: "app.bsky.feed.like",
      record: record
    })
  end

  @doc """
  Unlikes a post by deleting the like record.

  ## Examples

      {:ok, _} = Bsky.unlike(session, like.uri)
  """
  @spec unlike(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def unlike(session, like_uri) when is_binary(like_uri) do
    delete_record(session, like_uri)
  end

  @doc """
  Reposts a post.

  ## Examples

      {:ok, repost} = Bsky.repost(session, post.uri, post.cid)
  """
  @spec repost(session(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def repost(session, uri, cid) when is_binary(uri) and is_binary(cid) do
    record = %{
      "$type": "app.bsky.feed.repost",
      subject: %{uri: uri, cid: cid},
      created_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Repo.create_record(session, %{
      repo: Session.did(session),
      collection: "app.bsky.feed.repost",
      record: record
    })
  end

  @doc """
  Follows an actor.

  ## Examples

      {:ok, follow} = Bsky.follow(session, "alice.bsky.social")
      {:ok, follow} = Bsky.follow(session, "did:plc:abc123")
  """
  @spec follow(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def follow(session, actor) when is_binary(actor) do
    with {:ok, did} <- resolve_actor(actor) do
      record = %{
        "$type": "app.bsky.graph.follow",
        subject: did,
        created_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      Repo.create_record(session, %{
        repo: Session.did(session),
        collection: "app.bsky.graph.follow",
        record: record
      })
    end
  end

  @doc """
  Unfollows an actor by deleting the follow record.

  ## Examples

      {:ok, _} = Bsky.unfollow(session, follow.uri)
  """
  @spec unfollow(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def unfollow(session, follow_uri) when is_binary(follow_uri) do
    delete_record(session, follow_uri)
  end

  @doc """
  Gets an actor's profile.

  ## Examples

      {:ok, profile} = Bsky.get_profile(session, "alice.bsky.social")
  """
  @spec get_profile(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_profile(session, actor) when is_binary(actor) do
    Actor.get_profile(session, %{actor: actor})
  end

  @doc """
  Gets the authenticated user's timeline.

  ## Options

  - `:limit` - Number of posts (default: 50, max: 100)
  - `:cursor` - Pagination cursor

  ## Examples

      {:ok, %{feed: posts, cursor: cursor}} = Bsky.get_timeline(session)
      {:ok, %{feed: more}} = Bsky.get_timeline(session, cursor: cursor)
  """
  @spec get_timeline(session(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_timeline(session, opts \\ []) do
    params = %{
      limit: Keyword.get(opts, :limit, 50)
    }

    params =
      case Keyword.get(opts, :cursor) do
        nil -> params
        cursor -> Map.put(params, :cursor, cursor)
      end

    Feed.get_timeline(session, params)
  end

  @doc """
  Gets a post thread with context.

  ## Options

  - `:depth` - How many levels of replies to fetch (default: 6)
  - `:parent_height` - How many levels of parent posts to fetch (default: 80)

  ## Examples

      {:ok, thread} = Bsky.get_post_thread(session, post_uri)
  """
  @spec get_post_thread(session(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_post_thread(session, uri, opts \\ []) when is_binary(uri) do
    params = %{
      uri: uri,
      depth: Keyword.get(opts, :depth, 6),
      parent_height: Keyword.get(opts, :parent_height, 80)
    }

    Feed.get_post_thread(session, params)
  end

  @doc """
  Gets multiple posts by their AT-URIs.

  ## Examples

      uris = ["at://did:plc:xyz/app.bsky.feed.post/123", "at://..."]
      {:ok, posts} = Bsky.get_posts(session, uris)
  """
  @spec get_posts(session(), [String.t()]) :: {:ok, map()} | {:error, term()}
  def get_posts(session, uris) when is_list(uris) do
    Feed.get_posts(session, %{uris: uris})
  end

  @doc """
  Gets multiple actor profiles.

  ## Examples

      {:ok, profiles} = Bsky.get_profiles(session, ["alice.bsky.social", "bob.bsky.social"])
  """
  @spec get_profiles(session(), [String.t()]) :: {:ok, map()} | {:error, term()}
  def get_profiles(session, actors) when is_list(actors) do
    Actor.get_profiles(session, %{actors: actors})
  end

  @doc """
  Updates the authenticated user's profile.

  Fetches the current `app.bsky.actor.profile` record, merges the given
  changes, and writes it back, so fields not mentioned are preserved.

  ## Options

  - `:display_name` - New display name
  - `:description` - New profile description (bio)
  - `:avatar` - `{data, content_type}` tuple with the raw image bytes and
    its MIME type. The data is uploaded as a blob and linked in the record.

  ## Examples

      {:ok, _} = Bsky.update_profile(session, display_name: "Alice")

      {:ok, _} =
        Bsky.update_profile(session,
          display_name: "Alice",
          description: "Posting about Elixir",
          avatar: {File.read!("avatar.png"), "image/png"}
        )
  """
  @spec update_profile(session(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_profile(session, updates) when is_list(updates) do
    with {:ok, current} <- current_profile(session),
         {:ok, avatar} <- maybe_upload_avatar(session, Keyword.get(updates, :avatar)) do
      record =
        current
        |> maybe_update(:display_name, Keyword.get(updates, :display_name))
        |> maybe_update(:description, Keyword.get(updates, :description))
        |> maybe_update(:avatar, avatar)
        |> Map.put(:"$type", "app.bsky.actor.profile")

      Repo.put_record(session, %{
        repo: Session.did(session),
        collection: "app.bsky.actor.profile",
        rkey: "self",
        record: record
      })
    end
  end

  @doc """
  Searches for posts matching a query.

  ## Options

  - `:sort` - `:top` or `:latest`
  - `:since` - Only posts after this `Date`
  - `:until` - Only posts before this `Date`
  - `:author` - Restrict to posts by this actor (handle or DID)
  - `:lang` - Restrict to this language code
  - `:domain` - Restrict to posts linking to this domain
  - `:url` - Restrict to posts linking to this URL
  - `:mentions` - Restrict to posts mentioning these actors
  - `:tag` - Restrict to posts with these hashtags
  - `:limit` - Number of posts (default: 25, max: 100)
  - `:cursor` - Pagination cursor

  ## Examples

      {:ok, %{posts: posts}} = Bsky.search_posts(session, "elixir lang")
      {:ok, %{posts: latest}} = Bsky.search_posts(session, "elixir", sort: :latest)
  """
  @spec search_posts(session(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def search_posts(session, query, opts \\ []) when is_binary(query) do
    params =
      opts
      |> Keyword.take([:sort, :since, :until, :author, :lang, :domain, :url, :mentions, :tag, :limit, :cursor])
      |> Map.new()
      |> Map.put(:q, query)
      |> Map.put_new(:limit, 25)

    Feed.search_posts(session, params)
  end

  @doc """
  Searches for actors (profiles) matching a query.

  ## Options

  - `:limit` - Number of actors (default: 25, max: 100)
  - `:cursor` - Pagination cursor

  ## Examples

      {:ok, %{actors: actors}} = Bsky.search_actors(session, "alice")
  """
  @spec search_actors(session(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def search_actors(session, query, opts \\ []) when is_binary(query) do
    params =
      opts
      |> Keyword.take([:limit, :cursor])
      |> Map.new()
      |> Map.put(:q, query)
      |> Map.put_new(:limit, 25)

    Actor.search_actors(session, params)
  end

  @doc """
  Blocks an actor.

  ## Examples

      {:ok, block} = Bsky.block(session, "spammer.bsky.social")
      {:ok, block} = Bsky.block(session, "did:plc:xyz123")
  """
  @spec block(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def block(session, actor) when is_binary(actor) do
    with {:ok, did} <- resolve_actor(actor) do
      record = %{
        "$type": "app.bsky.graph.block",
        subject: did,
        created_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      Repo.create_record(session, %{
        repo: Session.did(session),
        collection: "app.bsky.graph.block",
        record: record
      })
    end
  end

  @doc """
  Unblocks an actor by deleting the block record.

  ## Examples

      {:ok, _} = Bsky.unblock(session, block.uri)
  """
  @spec unblock(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def unblock(session, block_uri) when is_binary(block_uri) do
    delete_record(session, block_uri)
  end

  @doc """
  Mutes an actor (client-side muting via XRPC).

  ## Examples

      {:ok, _} = Bsky.mute(session, "noisy.bsky.social")
  """
  @spec mute(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def mute(session, actor) when is_binary(actor) do
    Graph.mute_actor(session, %{actor: actor})
  end

  @doc """
  Unmutes an actor.

  ## Examples

      {:ok, _} = Bsky.unmute(session, "noisy.bsky.social")
  """
  @spec unmute(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def unmute(session, actor) when is_binary(actor) do
    Graph.unmute_actor(session, %{actor: actor})
  end

  @doc """
  Deletes any record owned by the session's account by its AT-URI.

  The typed `unlike/2`, `unfollow/2`, `unblock/2`, `delete_post/2` and
  `unrepost/2` helpers all delegate here.

  ## Examples

      {:ok, _} = Bsky.delete_record(session, "at://did:plc:xyz/app.bsky.feed.post/3k...")
  """
  @spec delete_record(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_record(session, uri) when is_binary(uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(uri) do
      Repo.delete_record(session, %{
        repo: repo,
        collection: collection,
        rkey: rkey
      })
    end
  end

  @doc """
  Deletes a post by its AT-URI.

  ## Examples

      {:ok, _} = Bsky.delete_post(session, post.uri)
  """
  @spec delete_post(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_post(session, post_uri) when is_binary(post_uri) do
    delete_record(session, post_uri)
  end

  @doc """
  Unrepost by deleting the repost record.

  ## Examples

      {:ok, _} = Bsky.unrepost(session, repost.uri)
  """
  @spec unrepost(session(), String.t()) :: {:ok, map()} | {:error, term()}
  def unrepost(session, repost_uri) when is_binary(repost_uri) do
    delete_record(session, repost_uri)
  end

  @doc """
  Lists notifications for the authenticated user.

  ## Options

  - `:limit` - Number of notifications (default: 50)
  - `:cursor` - Pagination cursor
  - `:seen_at` - Only return notifications after this timestamp

  ## Examples

      {:ok, %{notifications: notifs, cursor: cursor}} = Bsky.list_notifications(session)
  """
  @spec list_notifications(session(), keyword()) :: {:ok, map()} | {:error, term()}
  def list_notifications(session, opts \\ []) do
    params = %{
      limit: Keyword.get(opts, :limit, 50)
    }

    params =
      case Keyword.get(opts, :cursor) do
        nil -> params
        cursor -> Map.put(params, :cursor, cursor)
      end

    params =
      case Keyword.get(opts, :seen_at) do
        nil -> params
        seen_at -> Map.put(params, :seen_at, seen_at)
      end

    Notification.list_notifications(session, params)
  end

  @doc """
  Publishes an `app.bsky.feed.generator` record, pointing the network at
  a feed service.

  `did` is the DID of the service serving `getFeedSkeleton`; see
  `ProtoRune.Bsky.FeedGen` for the serving-side helpers and the record
  options.

  ## Examples

      {:ok, feed} = Bsky.publish_feed(session, "did:web:feeds.example.com",
        display_name: "Elixir",
        description: "All things Elixir",
        accepts_interactions: true
      )
  """
  @spec publish_feed(session(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def publish_feed(session, did, opts) when is_binary(did) do
    params = %{
      repo: Session.did(session),
      collection: "app.bsky.feed.generator",
      record: FeedGen.generator_record(did, opts)
    }

    params =
      case Keyword.get(opts, :rkey) do
        nil -> params
        rkey -> Map.put(params, :rkey, rkey)
      end

    Repo.create_record(session, params)
  end

  @doc """
  Gets the count of unread notifications.

  ## Examples

      {:ok, %{count: unread}} = Bsky.get_unread_count(session)
  """
  @spec get_unread_count(session()) :: {:ok, map()} | {:error, term()}
  def get_unread_count(session) do
    Notification.get_unread_count(session, %{})
  end

  @doc """
  Marks notifications as seen up to a given timestamp.

  ## Examples

      :ok = Bsky.update_seen(session, DateTime.utc_now())
  """
  @spec update_seen(session(), DateTime.t()) :: {:ok, map()} | {:error, term()}
  def update_seen(session, seen_at) do
    Notification.update_seen(session, %{
      seen_at: DateTime.to_iso8601(seen_at)
    })
  end

  defp resolve_actor("did:" <> _ = did), do: {:ok, did}

  defp resolve_actor(handle) do
    Identity.resolve_handle(handle)
  end

  # A missing profile record means the account has no profile yet, so the
  # update starts from an empty record.
  defp current_profile(session) do
    case Repo.get_record(session,
           repo: Session.did(session),
           collection: "app.bsky.actor.profile",
           rkey: "self"
         ) do
      {:ok, %{value: value}} -> {:ok, value}
      {:error, %Error{reason: reason}} when reason in [:not_found, :record_not_found] -> {:ok, %{}}
      {:error, _} = error -> error
    end
  end

  defp maybe_upload_avatar(_session, nil), do: {:ok, nil}

  defp maybe_upload_avatar(session, {data, content_type}) do
    with {:ok, %{blob: blob}} <- Repo.upload_blob(session, data, content_type) do
      {:ok, blob}
    end
  end

  defp maybe_update(record, _key, nil), do: record
  defp maybe_update(record, key, value), do: Map.put(record, key, value)

  defp maybe_put_reply(session, record, opts) do
    case Keyword.get(opts, :reply_to) do
      nil ->
        {:ok, record}

      uri ->
        case build_reply(session, uri) do
          {:ok, reply} -> {:ok, Map.put(record, :reply, reply)}
          {:error, _} = error -> error
        end
    end
  end

  # Fetches the parent post, then builds strong refs from the pure reply_refs/3.
  defp build_reply(session, uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(uri),
         {:ok, %{cid: cid, value: value}} <-
           Repo.get_record(session, repo: repo, collection: collection, rkey: rkey) do
      {:ok, reply_refs(uri, cid, value)}
    end
  end

  # Root comes from the parent's own reply.root when the parent is itself a
  # reply, otherwise the parent is the root.
  defp reply_refs(parent_uri, parent_cid, parent_value) do
    parent = %{uri: parent_uri, cid: parent_cid}

    root =
      case parent_value do
        %{reply: %{root: root}} -> root
        _ -> parent
      end

    %{root: root, parent: parent}
  end

  defp parse_at_uri(uri), do: ProtoRune.Atproto.parse_at_uri(uri)
end
