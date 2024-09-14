defmodule Bsky.Chat.Actor do
  @moduledoc false

  import XRPC.DSL

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-delete-account
  """
  defprocedure("chat.bsky.actor.deleteAccount", authenticated: true)
end
