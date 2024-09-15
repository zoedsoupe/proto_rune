defmodule Bsky.Chat.Moderation do
  @moduledoc false

  import XRPC.DSL

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-moderation-get-actor-metadata
  """
  defquery "chat.bsky.moderation.getActorMetadata", for: :todo do
    param :actor, {:required, :string}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-moderation-get-message-context
  """
  defquery "chat.bsky.moderation.getMessageContext", for: :todo do
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
