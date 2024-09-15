defmodule ProtoRune.Bsky.Graph do
  @moduledoc false

  import ProtoRune.XRPC.DSL

  @doc """
  Get a list of starter packs created by the actor.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-actor-starter-packs
  """
  defquery "app.bsky.graph.getActorStarterPacks", for: :actor do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates which accounts the requesting account is currently blocking. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-blocks
  """
  defquery "app.bsky.graph.getBlocks", authenticated: true

  defquery "app.bsky.graph.getBlocks", authenticated: true do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates accounts which follow a specified account (actor).

  https://docs.bsky.app/docs/api/app-bsky-graph-get-followers
  """
  defquery "app.bsky.graph.getFollowers", for: :todo do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates accounts which a specified account (actor) follows.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-follows
  """
  defquery "app.bsky.graph.getFollows", for: :todo do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates accounts which follow a specified account (actor) and are followed by the viewer.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-known-followers
  """
  defquery "app.bsky.graph.getKnownFollowers", for: :todo do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get mod lists that the requesting account (actor) is blocking. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-list-blocks
  """
  defquery "app.bsky.graph.getListBlocks", authenticated: true

  defquery "app.bsky.graph.getListBlocks", authenticated: true do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-list-mutes
  """
  defquery "app.bsky.graph.getListMutes", authenticated: true

  defquery "app.bsky.graph.getListMutes", authenticated: true do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Gets a 'view' (with additional context) of a specified list.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-list
  """
  defquery "app.bsky.graph.getList", for: :Todo do
    param :list, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates the lists created by a specified account (actor).

  https://docs.bsky.app/docs/api/app-bsky-graph-get-lists
  """
  defquery "app.bsky.graph.getLists", for: :Todo do
    param :actor, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-mutes
  """
  defquery "app.bsky.graph.getMutes", for: :todo

  defquery "app.bsky.graph.getMutes", for: :todo do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Enumerates public relationships between one account, and a list of other accounts. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-relationships
  """
  defquery "app.bsky.graph.getRelationShips", for: :todo do
    param :actor, {:required, :string}
    param :others, {:list, :string}
  end

  @doc """
  Gets a view of a starter pack.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-starter-pack
  """
  defquery "app.bsky.graph.getStarterPack", for: :todo do
    param :starter_pack, {:required, :string}
  end

  @doc """
  Get views for a list of starter packs.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-starter-packs
  """
  defquery "app.bsky.graph.getStarterPacks", for: :todo do
    param :uris, {:required, {:list, :string}}
  end

  @doc """
  Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.

  https://docs.bsky.app/docs/api/app-bsky-graph-get-suggested-follows-by-actor
  """
  defquery "app.bsky.graph.getSuggestedFollowsByActor", for: :todo do
    param :actor, {:required, :string}
  end

  @doc """
  Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-mute-actor-list
  """
  defprocedure "app.bsky.graph.muteActorList", authenticated: true do
    param :list, {:required, :string}
  end

  @doc """
  Creates a mute relationship for the specified account. Mutes are private in Bluesky. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-mute-actor
  """
  defprocedure "app.bsky.graph.muteActor", authenticated: true do
    param :actor, {:required, :string}
  end

  @doc """
  Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-mute-thread
  """
  defprocedure "app.bsky.graph.muteThread", authenticated: true do
    param :root, {:required, :string}
  end

  @doc """
  Unmutes the specified list of accounts. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-unmute-actor-list
  """
  defprocedure "app.bsky.graph.unmuteActorList", authenticated: true do
    param :list, {:required, :string}
  end

  @doc """
  Unmutes the specified account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-unmute-actor
  """
  defprocedure "app.bsky.graph.unmuteActor", authenticated: true do
    param :actor, {:required, :string}
  end

  @doc """
  Unmutes the specified thread. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-graph-unmute-thread
  """
  defprocedure "app.bsky.graph.unmuteThread", authenticated: true do
    param :root, {:required, :string}
  end
end
