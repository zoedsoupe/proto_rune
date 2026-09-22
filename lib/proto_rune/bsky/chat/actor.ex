defmodule ProtoRune.Bsky.Chat.Actor do
  @moduledoc """
  Chat actor endpoints of the Bluesky lexicon (`chat.bsky.actor.*`).

  Generated XRPC functions; call them as `Actor.endpoint(session, %{param: value})`.
  Conversation endpoints live in `ProtoRune.Bsky.Chat.Convo`.
  """

  import ProtoRune.XRPC.DSL

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-delete-account
  """
  defprocedure "chat.bsky.actor.deleteAccount", authenticated: true

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-export-account-data
  """
  defquery "chat.bsky.actor.exportAccountData", authenticated: true
end
