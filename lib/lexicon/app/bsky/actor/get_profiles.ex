defmodule Lexicon.App.Bsky.Actor.GetProfiles do
  @moduledoc """
  Query to get multiple actor profiles.

  NSID: app.bsky.actor.getProfiles
  """

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.ProfileViewDetailed

  @param_types %{
    actors: {:array, :string}
  }

  @output_types %{
    profiles: {:array, :map} # Array of ProfileViewDetailed
  }

  @doc """
  Validates the parameters for getting multiple profiles.
  """
  def validate_params(params) when is_map(params) do
    changeset = 
      {%{}, @param_types}
      |> cast(params, Map.keys(@param_types))
      |> validate_required([:actors])
      |> validate_length(:actors, min: 1, max: 25)

    # Validate that each actor is a handle or DID
    if actors = get_field(changeset, :actors) do
      actors
      |> Enum.reduce_while(changeset, fn actor, acc ->
        if is_binary(actor) && Regex.match?(~r/^(did:|@)/, actor) do
          {:cont, acc}
        else
          {:halt, add_error(acc, :actors, "must all be handles or DIDs")}
        end
      end)
      |> apply_action(:validate)
    else
      apply_action(changeset, :validate)
    end
  end

  @doc """
  Validates the output from getting multiple profiles.
  """
  def validate_output(output) when is_map(output) do
    changeset = 
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:profiles])

    with %{valid?: true} = changeset <- changeset,
         profiles = get_field(changeset, :profiles) do
      
      # Validate each profile in the list
      validated_profiles = 
        Enum.reduce_while(profiles, {:ok, []}, fn profile, {:ok, acc} ->
          case ProfileViewDetailed.validate(profile) do
            {:ok, validated_profile} -> {:cont, {:ok, [validated_profile | acc]}}
            error -> {:halt, error}
          end
        end)

      case validated_profiles do
        {:ok, validated_list} ->
          validated_output = apply_changes(changeset)
          {:ok, %{validated_output | profiles: Enum.reverse(validated_list)}}
        
        error -> error
      end
    else
      %{valid?: false} = changeset -> {:error, changeset}
    end
  end
end