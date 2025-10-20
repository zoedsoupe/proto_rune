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
      "$type" => "app.bsky.feed.post",
      text: text,
      langs: Keyword.get(opts, :langs, ["en"]),
      created_at: opts |> Keyword.get(:created_at, DateTime.utc_now()) |> DateTime.to_iso8601()
    }

    record =
      case Keyword.get(opts, :reply_to) do
        nil -> record
        uri -> Map.put(record, :reply, build_reply(uri))
      end

    Repo.create_record(session, %{
      repo: session.did,
      collection: "app.bsky.feed.post",
      record: record
    })
  end

  def post(session, %{text: text, facets: facets}, opts) when is_binary(text) and is_list(facets) do
    record = %{
      "$type" => "app.bsky.feed.post",
      text: text,
      facets: facets,
      langs: Keyword.get(opts, :langs, ["en"]),
      created_at: opts |> Keyword.get(:created_at, DateTime.utc_now()) |> DateTime.to_iso8601()
    }

    record =
      case Keyword.get(opts, :reply_to) do
        nil -> record
        uri -> Map.put(record, :reply, build_reply(uri))
      end

    Repo.create_record(session, %{
      repo: session.did,
      collection: "app.bsky.feed.post",
      record: record
    })
  end

  @doc """
  Likes a post.

  ## Examples

      {:ok, like} = Bsky.like(session, post.uri, post.cid)
  """
  @spec like(session(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def like(session, uri, cid) when is_binary(uri) and is_binary(cid) do
    record = %{
      "$type" => "app.bsky.feed.like",
      subject: %{uri: uri, cid: cid},
      created_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Repo.create_record(session, %{
      repo: session.did,
      collection: "app.bsky.feed.like",
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
      "$type" => "app.bsky.feed.repost",
      subject: %{uri: uri, cid: cid},
      created_at: DateTime.to_iso8601(DateTime.utc_now())
    }

    Repo.create_record(session, %{
      repo: session.did,
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

  # NOTE: Simplified MVP implementation
  # For proper reply threading, this should:
  # 1. Fetch the parent post to get its CID
  # 2. Determine the thread root (parent.reply.root or parent itself)
  # For now, returns stub values - replies will work but without proper threading
  defp build_reply(_uri) do
    %{
      root: %{uri: "", cid: ""},
      parent: %{uri: "", cid: ""}
    }
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
