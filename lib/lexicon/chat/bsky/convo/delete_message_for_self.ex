defmodule Lexicon.Chat.Bsky.Convo.DeleteMessageForSelf do
  @moduledoc """
  Procedure to delete a message for self.

  NSID: chat.bsky.convo.deleteMessageForSelf
  """

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Convo.DeletedMessageView

  @input_types %{
    convo_id: :string,
    message_id: :string
  }

  @doc """
  Validates the input for deleting a message for self.
  """
  def validate_input(input) when is_map(input) do
    {%{}, @input_types}
    |> cast(input, Map.keys(@input_types))
    |> validate_required([:convo_id, :message_id])
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from deleting a message for self.
  """
  def validate_output(output) when is_map(output) do
    DeletedMessageView.validate(output)
  end
end