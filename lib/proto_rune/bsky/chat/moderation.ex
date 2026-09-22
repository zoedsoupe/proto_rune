defmodule ProtoRune.Bsky.Chat.Moderation do
  @moduledoc """
  Chat moderation endpoints of the Bluesky lexicon (`chat.bsky.moderation.*`).

  Generated XRPC functions; call them as `Moderation.endpoint(session, %{param: value})`.
  """

  import ProtoRune.XRPC.DSL

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-moderation-get-actor-metadata
  """
  defquery "chat.bsky.moderation.getActorMetadata" do
    param :actor, {:required, :string}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-moderation-get-message-context
  """
  defquery "chat.bsky.moderation.getMessageContext" do
    param :convo_id, {:required, :string}
    param :message_id, {:required, :string}
    param :before, :integer
    param :after, :integer
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-moderation-update-actor-access
  """
  defprocedure "chat.bsky.moderation.updateActorAccess", authenticated: true do
    param :actor, {:required, :string}
    param :allow_access, {:required, :boolean}
    param :ref, :string
  end
end
