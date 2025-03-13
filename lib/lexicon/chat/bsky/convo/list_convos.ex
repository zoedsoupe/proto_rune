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
    # Array of ConvoView
    convos: {:array, :map}
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
         convos = get_field(changeset, :convos),
         {:ok, validated_list} <- validate_convo_list(convos) do
      validated_output = apply_changes(changeset)
      {:ok, %{validated_output | convos: Enum.reverse(validated_list)}}
    else
      %{valid?: false} = changeset -> {:error, changeset}
      error -> error
    end
  end

  defp validate_convo_list(convos) do
    Enum.reduce_while(convos, {:ok, []}, fn convo, {:ok, acc} ->
      case ConvoView.validate(convo) do
        {:ok, validated_convo} -> {:cont, {:ok, [validated_convo | acc]}}
        error -> {:halt, error}
      end
    end)
  end
end
