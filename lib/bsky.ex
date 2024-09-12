defmodule Bsky do
  @moduledoc false

  alias Atproto.Session
  alias Bsky.Schema
  alias XRPC.Client
  alias XRPC.Query

  def get_profile(%Session{} = session, actor: actor) do
    query = Schema.app_bsky_actor_get_profile()

    query
    |> Query.put_param(:actor, actor)
    |> Query.put_header("authorization", "Bearer #{session.access_jwt}")
    |> Client.execute()
  end
end
