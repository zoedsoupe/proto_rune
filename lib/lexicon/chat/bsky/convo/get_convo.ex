defmodule Lexicon.Chat.Bsky.Convo.GetConvo do
  @moduledoc """
  Query to retrieve a conversation.

  NSID: chat.bsky.convo.getConvo
  """

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Convo.ConvoView

  @param_types %{
    convo_id: :string
  }

  @output_types %{
    convo: :map # A ConvoView
  }

  @doc """
  Validates the parameters for getting a conversation.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:convo_id])
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from getting a conversation.
  """
  def validate_output(output) when is_map(output) do
    changeset = 
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:convo])

    with %{valid?: true} = changeset <- changeset,
         convo = get_field(changeset, :convo),
         {:ok, validated_convo} <- ConvoView.validate(convo) do
      
      validated_output = apply_changes(changeset)
      
      {:ok, %{validated_output | convo: validated_convo}}
    else
      %{valid?: false} = changeset -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end
end