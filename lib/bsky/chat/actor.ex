defmodule Bsky.Chat.Actor do
  @moduledoc false

  import XRPC.DSL

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-delete-account
  """
  defprocedure "chat.bsky.actor.deleteAccount", authenticated: true

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-export-account-data
  """
  defquery "chat.bsky.actor.exportAccountData", authenticated: true

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-delete-message-for-self
  """
  defprocedure "chat.bsky.convo.deleteMessageForSelf", authenticated: true do
    param :convo_id, {:required, :string}
    param :message_id, {:required, :string}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-get-convo-for-members
  """
  defquery "chat.bsky.convo.getConvoForMembers", for: :todo do
    param :members, {:required, {:list, :string}}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-get-convo
  """
  defquery "chat.bsky.convo.getConvo", for: :todo do
    param :convo_id, {:required, :string}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-actor-get-log
  """
  defquery "chat.bsky.convo.getLog", authenticated: true

  defquery "chat.bsky.convo.getLog", authenticated: true do
    param :cursor, :string
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-get-messages
  """
  defquery "chat.bsky.convo.getMessages", authenticated: true do
    param :convo_id, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-leave-convo
  """
  defprocedure "chat.bsky.convo.leaveConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-list-convos
  """
  defquery "chat.bsky.convo.listConvos", authenticated: true

  defquery "chat.bsky.convo.listConvos", authenticated: true do
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-mute-convo
  """
  defprocedure "chat.bsky.convo.muteConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @message %{
    text: {:required, :string},
    facets:
      {:list,
       %{
         index: %{
           byte_start: {:required, :integer},
           byte_end: {:required, :integer}
         },
         features: {:required, {:list, :string}}
       }},
    embed: %{
      record: %{
        uri: {:required, :string},
        cid: {:required, :string}
      }
    }
  }

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-send-message-batch
  """
  defprocedure "chat.bsky.convo.sendMessageBatch", authenticated: true do
    param :items,
          {:required,
           {:list,
            %{
              convo_id: {:required, :string},
              message: {:required, @message}
            }}}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-send-message
  """
  defprocedure "chat.bsky.convo.sendMessage", authenticated: true do
    param :convo_id, {:required, :string}
    param :message, {:required, @message}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-unmute-convo
  """
  defprocedure "chat.bsky.convo.unmuteConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  https://docs.bsky.app/docs/api/chat-bsky-convo-update-read
  """
  defprocedure "chat.bsky.convo.updateRead", authenticated: true do
    param :convo_id, {:required, :string}
    param :message_id, {:required, :string}
  end
end
