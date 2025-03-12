defmodule Lexicon.Chat.Bsky.Convo.LeaveConvo do
  @moduledoc """
  Procedure to leave a conversation.

  NSID: chat.bsky.convo.leaveConvo
  """

  import Ecto.Changeset

  @input_types %{
    convo_id: :string
  }

  @output_types %{
    convo_id: :string,
    rev: :string
  }

  @doc """
  Validates the input for leaving a conversation.
  """
  def validate_input(input) when is_map(input) do
    {%{}, @input_types}
    |> cast(input, Map.keys(@input_types))
    |> validate_required([:convo_id])
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from leaving a conversation.
  """
  def validate_output(output) when is_map(output) do
    {%{}, @output_types}
    |> cast(output, Map.keys(@output_types))
    |> validate_required([:convo_id, :rev])
    |> apply_action(:validate)
  end
end