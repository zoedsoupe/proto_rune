defmodule ProtoRune.Bsky.Actor do
  @moduledoc false

  import ProtoRune.XRPC.DSL

  @doc """
  Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-preferences
  """
  defquery "app.bsky.actor.getPreferences", authenticated: true

  @doc """
  Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-profile
  """
  defquery "app.bsky.actor.getProfile", for: :profile do
    param :actor, {:required, :string}
  end

  defquery "app.bsky.actor.getProfile", authenticated: true do
    param :actor, {:required, :string}
  end

  @doc """
  Get detailed profile views of multiple actors.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-profiles
  """
  defquery "app.bsky.actor.getProfiles", for: :profile do
    param :actors, {:required, {:list, :string}}
  end

  defquery "app.bsky.actor.getProfiles", authenticated: true do
    param :actors, {:required, {:list, :string}}
  end

  @doc """
  Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.

  https://docs.bsky.app/docs/api/app-bsky-actor-get-suggestions
  """
  defquery "app.bsky.actor.getSuggestions", authenticated: true

  defquery "app.bsky.actor.getSuggestions", authenticated: true do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Set the private preferences attached to the account.

  https://docs.bsky.app/docs/api/app-bsky-actor-put-preferences
  """
  defprocedure "app.bsky.actor.putPreferences", authenticated: true do
    # implementar schemas
    param :preferences, {:required, :map}
  end

  @doc """
  Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-search-actors-typeahead
  """
  defquery "app.bsky.actor.searchActorsTypeahead", for: :search_actors

  defquery "app.bsky.actor.searchActorsTypeahead", for: :search_actors do
    param :q, :string
    param :limit, :integer
  end

  @doc """
  Find actors (profiles) matching search criteria. Does not require auth.

  https://docs.bsky.app/docs/api/app-bsky-actor-search-actors
  """
  defquery "app.bsky.actor.searchActors", for: :search_actors

  defquery "app.bsky.actor.searchActors", for: :search_actors do
    param :q, :string
    param :limit, :integer
    param :cursor, :string
  end
end
