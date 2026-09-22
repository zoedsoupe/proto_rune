defmodule ProtoRune.Bsky.Chat.Convo do
  @moduledoc """
  Conversation endpoints of the Bluesky chat lexicon (`chat.bsky.convo.*`).

  Generated XRPC functions; call them as `Convo.endpoint(session, %{param: value})`.
  All convo endpoints require auth.
  """

  import ProtoRune.XRPC.DSL

  @doc """
  Accept a conversation request.

  https://docs.bsky.app/docs/api/chat-bsky-convo-accept-convo
  """
  defprocedure "chat.bsky.convo.acceptConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  Add a reaction to a message.

  https://docs.bsky.app/docs/api/chat-bsky-convo-add-reaction
  """
  defprocedure "chat.bsky.convo.addReaction", authenticated: true do
    param :convo_id, {:required, :string}
    param :message_id, {:required, :string}
    param :value, {:required, :string}
  end

  @doc """
  Delete a message for the requesting account.

  https://docs.bsky.app/docs/api/chat-bsky-convo-delete-message-for-self
  """
  defprocedure "chat.bsky.convo.deleteMessageForSelf", authenticated: true do
    param :convo_id, {:required, :string}
    param :message_id, {:required, :string}
  end

  @doc """
  Get a conversation by id.

  https://docs.bsky.app/docs/api/chat-bsky-convo-get-convo
  """
  defquery "chat.bsky.convo.getConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  Get the conversation availability for a list of members.

  https://docs.bsky.app/docs/api/chat-bsky-convo-get-convo-availability
  """
  defquery "chat.bsky.convo.getConvoAvailability", authenticated: true do
    param :members, {:required, {:list, :string}}
  end

  @doc """
  Get the conversation with a list of members, creating it when missing.

  https://docs.bsky.app/docs/api/chat-bsky-convo-get-convo-for-members
  """
  defquery "chat.bsky.convo.getConvoForMembers", authenticated: true do
    param :members, {:required, {:list, :string}}
  end

  @doc """
  Get the message log for the requesting account.

  https://docs.bsky.app/docs/api/chat-bsky-convo-get-log
  """
  defquery "chat.bsky.convo.getLog", authenticated: true do
    param :cursor, :string
  end

  @doc """
  Get messages in a conversation.

  https://docs.bsky.app/docs/api/chat-bsky-convo-get-messages
  """
  defquery "chat.bsky.convo.getMessages", authenticated: true do
    param :convo_id, {:required, :string}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Leave a conversation.

  https://docs.bsky.app/docs/api/chat-bsky-convo-leave-convo
  """
  defprocedure "chat.bsky.convo.leaveConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  List the requesting account's conversations.

  https://docs.bsky.app/docs/api/chat-bsky-convo-list-convos
  """
  defquery "chat.bsky.convo.listConvos", authenticated: true do
    param :limit, :integer
    param :cursor, :string
    param :read_state, {:enum, [:unread]}
    param :status, {:enum, [:request, :accepted]}
  end

  @doc """
  Mute a conversation.

  https://docs.bsky.app/docs/api/chat-bsky-convo-mute-convo
  """
  defprocedure "chat.bsky.convo.muteConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  Remove a reaction from a message.

  https://docs.bsky.app/docs/api/chat-bsky-convo-remove-reaction
  """
  defprocedure "chat.bsky.convo.removeReaction", authenticated: true do
    param :convo_id, {:required, :string}
    param :message_id, {:required, :string}
    param :value, {:required, :string}
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
  Send a message to a conversation.

  https://docs.bsky.app/docs/api/chat-bsky-convo-send-message
  """
  defprocedure "chat.bsky.convo.sendMessage", authenticated: true do
    param :convo_id, {:required, :string}
    param :message, {:required, @message}
  end

  @doc """
  Send messages to several conversations at once.

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
  Unmute a conversation.

  https://docs.bsky.app/docs/api/chat-bsky-convo-unmute-convo
  """
  defprocedure "chat.bsky.convo.unmuteConvo", authenticated: true do
    param :convo_id, {:required, :string}
  end

  @doc """
  Mark all conversations as read.

  https://docs.bsky.app/docs/api/chat-bsky-convo-update-all-read
  """
  defprocedure "chat.bsky.convo.updateAllRead", authenticated: true do
    param :status, {:enum, [:request, :accepted]}
  end

  @doc """
  Mark a conversation as read up to a message.

  https://docs.bsky.app/docs/api/chat-bsky-convo-update-read
  """
  defprocedure "chat.bsky.convo.updateRead", authenticated: true do
    param :convo_id, {:required, :string}
    param :message_id, :string
  end
end
