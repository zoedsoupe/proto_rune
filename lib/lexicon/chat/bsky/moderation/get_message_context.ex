defmodule Lexicon.Chat.Bsky.Moderation.GetMessageContext do
  @moduledoc """
  Query to get context around a message for moderation purposes.

  NSID: chat.bsky.moderation.getMessageContext
  """

  import Ecto.Changeset

  @param_types %{
    convo_id: :string,
    message_id: :string,
    before: :integer,
    after: :integer
  }

  @output_types %{
    # Union of messageView and deletedMessageView
    messages: {:array, :map}
  }

  @doc """
  Validates the parameters for getting message context.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:message_id])
    |> validate_number(:before, greater_than_or_equal_to: 0)
    |> validate_number(:after, greater_than_or_equal_to: 0)
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from getting message context.
  """
  def validate_output(output) when is_map(output) do
    changeset =
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:messages])

    case changeset do
      %{valid?: true} = changeset ->
        # We don't validate the individual messages here because they could be
        # either MessageView or DeletedMessageView, and that validation happens
        # in the XRPC layer which understands the union types

        {:ok, apply_changes(changeset)}

      %{valid?: false} = changeset ->
        {:error, changeset}
    end
  end
end
