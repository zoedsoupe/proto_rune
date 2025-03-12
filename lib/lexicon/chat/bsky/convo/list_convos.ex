defmodule Lexicon.Chat.Bsky.Convo.ListConvos do
  @moduledoc """
  Query to list conversations.

  NSID: chat.bsky.convo.listConvos
  """

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Convo.ConvoView

  @param_types %{
    limit: :integer,
    cursor: :string
  }

  @output_types %{
    cursor: :string,
    convos: {:array, :map} # Array of ConvoView
  }

  @doc """
  Validates the parameters for listing conversations.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_number(:limit, greater_than: 0, less_than_or_equal_to: 100)
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from listing conversations.
  """
  def validate_output(output) when is_map(output) do
    changeset = 
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:convos])

    with %{valid?: true} = changeset <- changeset,
         convos = get_field(changeset, :convos) do
      
      # Validate each conversation in the list
      validated_convos = 
        Enum.reduce_while(convos, {:ok, []}, fn convo, {:ok, acc} ->
          case ConvoView.validate(convo) do
            {:ok, validated_convo} -> {:cont, {:ok, [validated_convo | acc]}}
            error -> {:halt, error}
          end
        end)

      case validated_convos do
        {:ok, validated_list} ->
          validated_output = apply_changes(changeset)
          {:ok, %{validated_output | convos: Enum.reverse(validated_list)}}
        
        error -> error
      end
    else
      %{valid?: false} = changeset -> {:error, changeset}
    end
  end
end