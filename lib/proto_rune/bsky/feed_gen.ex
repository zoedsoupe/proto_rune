defmodule ProtoRune.Bsky.FeedGen do
  @moduledoc """
  Helpers for building Bluesky feed generators.

  A feed generator is an HTTP service that answers three endpoints:

    * `app.bsky.feed.describeFeedGenerator` - advertises the feed URIs the
      service offers (see `describe/2`)
    * `app.bsky.feed.getFeedSkeleton` - returns an ordered list of post
      AT-URIs, which the AppView hydrates (see `skeleton/2`)
    * `app.bsky.feed.getFeed` (optional) - a hydrated variant

  The HTTP layer is the host application's job (Bandit, Plug, Phoenix);
  this module provides the pure protocol shapes those handlers return, plus
  `generator_record/2` for publishing the `app.bsky.feed.generator` record
  that points the network at the service.

  ## Examples

      # In a Plug handler:
      def get_feed_skeleton(conn, %{"feed" => feed, "limit" => limit, "cursor" => cursor}) do
        {:ok, posts, next_cursor} = MyFeed.posts(feed, limit, cursor)
        json(conn, FeedGen.skeleton(posts, next_cursor))
      end

      # Publishing the feed record:
      {:ok, feed} = Bsky.publish_feed(session, "did:web:feeds.example.com",
        display_name: "Elixir",
        description: "All things Elixir"
      )
  """

  @typedoc "A skeleton item: an AT-URI or a map with `:post` plus optional fields."
  @type skeleton_item :: String.t() | %{:post => String.t(), optional(atom()) => term()}

  @doc """
  Builds a `getFeedSkeleton` response body.

  `items` are post AT-URIs, either bare or as maps with `:post` and the
  optional `:feed_context` and `:reason` fields. `cursor` is `nil` when
  there are no more pages.

      iex> FeedGen.skeleton(["at://did:plc:a/app.bsky.feed.post/1"], "cursor2")
      %{feed: [%{post: "at://did:plc:a/app.bsky.feed.post/1"}], cursor: "cursor2"}
  """
  @spec skeleton([skeleton_item()], String.t() | nil) :: map()
  def skeleton(items, cursor \\ nil) when is_list(items) do
    %{feed: Enum.map(items, &skeleton_item/1), cursor: cursor}
  end

  defp skeleton_item(uri) when is_binary(uri), do: %{post: uri}
  defp skeleton_item(%{post: _uri} = item), do: item

  @doc """
  Builds a `describeFeedGenerator` response body advertising the feed URIs
  the service at `did` offers.

      iex> FeedGen.describe("did:web:feeds.example.com", ["at://did:plc:a/app.bsky.feed.generator/elixir"])
      %{did: "did:web:feeds.example.com", feeds: [%{uri: "at://did:plc:a/app.bsky.feed.generator/elixir"}]}
  """
  @spec describe(String.t(), [String.t()]) :: map()
  def describe(did, feed_uris) when is_binary(did) and is_list(feed_uris) do
    %{did: did, feeds: Enum.map(feed_uris, &%{uri: &1})}
  end

  @doc """
  Builds an `app.bsky.feed.generator` record for publishing.

  `did` is the DID of the feed service (where `getFeedSkeleton` is
  served). Options:

    * `:description` - longer description
    * `:description_facets` - rich text facets for the description
    * `:avatar` - blob reference (see `ProtoRune.Atproto.Repo.upload_blob/3`)
    * `:accepts_interactions` - boolean, opt into `sendInteractions`
    * `:created_at` - `DateTime` (default: now)
    * `:labels` - self-labels map
  """
  @spec generator_record(String.t(), keyword()) :: map()
  def generator_record(did, opts) when is_binary(did) do
    display_name =
      Keyword.get(opts, :display_name) ||
        raise ArgumentError, ":display_name is required"

    %{
      "$type": "app.bsky.feed.generator",
      did: did,
      display_name: display_name,
      created_at: opts |> Keyword.get(:created_at, DateTime.utc_now()) |> DateTime.to_iso8601()
    }
    |> maybe_put(:description, Keyword.get(opts, :description))
    |> maybe_put(:description_facets, Keyword.get(opts, :description_facets))
    |> maybe_put(:avatar, Keyword.get(opts, :avatar))
    |> maybe_put(:accepts_interactions, Keyword.get(opts, :accepts_interactions))
    |> maybe_put(:labels, Keyword.get(opts, :labels))
  end

  defp maybe_put(record, _key, nil), do: record
  defp maybe_put(record, key, value), do: Map.put(record, key, value)
end
