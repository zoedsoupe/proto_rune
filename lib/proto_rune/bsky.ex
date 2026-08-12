defmodule ProtoRune.Bsky do
  @moduledoc """
  High-level Bluesky API helpers.

  Provides ergonomic wrappers around repository operations and XRPC calls
  for common Bluesky tasks.

  ## Examples

      # Post
      {:ok, post} = Bsky.post(session, "Hello!")

      # Like
      {:ok, like} = Bsky.like(session, post_uri, post_cid)

      # Follow
      {:ok, follow} = Bsky.follow(session, "alice.bsky.social")

      # Get profile
      {:ok, profile} = Bsky.get_profile(session, "bob.bsky.social")
  """

  alias ProtoRune.Atproto.Identity
  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Bsky.Actor
  alias ProtoRune.Bsky.Feed
  alias ProtoRune.Bsky.Graph
  alias ProtoRune.Bsky.Notification
  alias ProtoRune.XRPC.Error

  @type session :: map()

  @doc """
  Posts a text message to Bluesky.

  Supports both plain text strings and RichText structs with facets.

  ## Options

  - `:langs` - List of language codes (default: `["en"]`)
  - `:reply_to` - AT-URI of post to reply to
  - `:created_at` - Timestamp (default: now)

  ## Examples

      # Simple text post
      {:ok, post} = Bsky.post(session, "Hello Bluesky!")

      # Reply to a post
      {:ok, reply} = Bsky.post(session, "Great point!",
        reply_to: "at://did:plc:xyz/app.bsky.feed.post/3k..."
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
    record = %{
      "$type": "app.bsky.feed.post",
      text: text,
      langs: Keyword.get(opts, :langs, ["en"]),
      created_at: opts |> Keyword.get(:created_at, DateTime.utc_now()) |> DateTime.to_iso8601()
    }

    with {:ok, record} <- maybe_put_reply(session, record, opts) do
      Repo.create_record(session, %{
        repo: session.did,
        collection: :post,
        record: record
      })
    end
  end

  def post(session, %{text: text, facets: facets}, opts) when is_binary(text) and is_list(facets) do
    record = %{
      "$type": "app.bsky.feed.post",
      text: text,
      facets: facets,
      langs: Keyword.get(opts, :langs, ["en"]),
      created_at: opts |> Keyword.get(:created_at, DateTime.utc_now()) |> DateTime.to_iso8601()
    }

    with {:ok, record} <- maybe_put_reply(session, record, opts) do
      Repo.create_record(session, %{
        repo: session.did,
        collection: :post,
        record: record
      })
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
      repo: session.did,
      collection: :like,
      record: record
    })
  end

  @doc """
  Unlikes a post by deleting the like record.

  ## Examples

      :ok = Bsky.unlike(session, like.uri)
  """
  @spec unlike(session(), String.t()) :: :ok | {:error, term()}
  def unlike(session, like_uri) when is_binary(like_uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(like_uri),
         {:ok, _} <-
           Repo.delete_record(session, %{
             repo: repo,
             collection: collection,
             rkey: rkey
           }) do
      :ok
    end
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
      repo: session.did,
      collection: :repost,
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
        "$type" => "app.bsky.graph.follow",
        subject: did,
        created_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      Repo.create_record(session, %{
        repo: session.did,
        collection: "app.bsky.graph.follow",
        record: record
      })
    end
  end

  @doc """
  Unfollows an actor by deleting the follow record.

  ## Examples

      :ok = Bsky.unfollow(session, follow.uri)
  """
  @spec unfollow(session(), String.t()) :: :ok | {:error, term()}
  def unfollow(session, follow_uri) when is_binary(follow_uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(follow_uri),
         {:ok, _} <-
           Repo.delete_record(session, %{
             repo: repo,
             collection: collection,
             rkey: rkey
           }) do
      :ok
    end
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
  def get_posts(_session, uris) when is_list(uris) do
    Feed.get_posts(%{uris: uris})
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
        repo: session.did,
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
        "$type" => "app.bsky.graph.block",
        subject: did,
        created_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      Repo.create_record(session, %{
        repo: session.did,
        collection: "app.bsky.graph.block",
        record: record
      })
    end
  end

  @doc """
  Unblocks an actor by deleting the block record.

  ## Examples

      :ok = Bsky.unblock(session, block.uri)
  """
  @spec unblock(session(), String.t()) :: :ok | {:error, term()}
  def unblock(session, block_uri) when is_binary(block_uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(block_uri),
         {:ok, _} <-
           Repo.delete_record(session, %{
             repo: repo,
             collection: collection,
             rkey: rkey
           }) do
      :ok
    end
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
  Deletes a post by its AT-URI.

  ## Examples

      :ok = Bsky.delete_post(session, post.uri)
  """
  @spec delete_post(session(), String.t()) :: :ok | {:error, term()}
  def delete_post(session, post_uri) when is_binary(post_uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(post_uri),
         {:ok, _} <-
           Repo.delete_record(session, %{
             repo: repo,
             collection: collection,
             rkey: rkey
           }) do
      :ok
    end
  end

  @doc """
  Unrepost by deleting the repost record.

  ## Examples

      :ok = Bsky.unrepost(session, repost.uri)
  """
  @spec unrepost(session(), String.t()) :: :ok | {:error, term()}
  def unrepost(session, repost_uri) when is_binary(repost_uri) do
    with {:ok, {repo, collection, rkey}} <- parse_at_uri(repost_uri),
         {:ok, _} <-
           Repo.delete_record(session, %{
             repo: repo,
             collection: collection,
             rkey: rkey
           }) do
      :ok
    end
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
           repo: session.did,
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

  defp parse_at_uri("at://" <> rest) do
    case String.split(rest, "/", parts: 3) do
      [repo, collection, rkey] ->
        {:ok, {repo, collection, rkey}}

      _ ->
        {:error, :malformed_at_uri}
    end
  end

  defp parse_at_uri(_uri) do
    {:error, :invalid_at_uri_format}
  end
end
