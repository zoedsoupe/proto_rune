defmodule Lexicon.Chat.Bsky.Convo.SendMessage do
  @moduledoc """
  Procedure to send a message in a conversation.

  NSID: chat.bsky.convo.sendMessage
  """

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Convo.MessageInput
  alias Lexicon.Chat.Bsky.Convo.MessageView

  @input_types %{
    convo_id: :string,
    message: :map # A MessageInput
  }

  @doc """
  Validates the input for sending a message.
  """
  def validate_input(input) when is_map(input) do
    changeset = 
      {%{}, @input_types}
      |> cast(input, Map.keys(@input_types))
      |> validate_required([:convo_id, :message])

    with %{valid?: true} = changeset <- changeset,
         message = get_field(changeset, :message),
         {:ok, validated_message} <- MessageInput.validate(message) do
      
      validated_input = apply_changes(changeset)
      
      {:ok, %{validated_input | message: validated_message}}
    else
      %{valid?: false} = changeset -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates the output from sending a message.
  """
  def validate_output(output) when is_map(output) do
    MessageView.validate(output)
  end
end