defmodule Lexicon.Chat.Bsky.Moderation.GetActorMetadata do
  @moduledoc """
  Query to get actor metadata for moderation purposes.

  NSID: chat.bsky.moderation.getActorMetadata
  """

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Moderation.Metadata

  @param_types %{
    actor: :string
  }

  @output_types %{
    day: :map,
    month: :map,
    all: :map
  }

  @doc """
  Validates the parameters for getting actor metadata.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:actor])
    |> validate_format(:actor, ~r/^did:/)
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from getting actor metadata.
  """
  def validate_output(output) when is_map(output) do
    changeset = 
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:day, :month, :all])

    with %{valid?: true} = changeset <- changeset,
         {:ok, day} <- Metadata.validate(get_field(changeset, :day)),
         {:ok, month} <- Metadata.validate(get_field(changeset, :month)),
         {:ok, all} <- Metadata.validate(get_field(changeset, :all)) do
      
      validated_output = apply_changes(changeset)
      
      {:ok, %{
        validated_output | 
        day: day, 
        month: month, 
        all: all
      }}
    else
      %{valid?: false} = changeset -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end
end