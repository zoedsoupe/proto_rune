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
    # Array of ProfileViewDetailed
    profiles: {:array, :map}
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
      |> validate_actors()

    apply_action(changeset, :validate)
  end

  defp validate_actors(changeset) do
    case get_field(changeset, :actors) do
      nil -> changeset
      actors -> validate_actor_identifiers(changeset, actors)
    end
  end

  defp validate_actor_identifiers(changeset, actors) do
    Enum.reduce_while(actors, changeset, fn actor, acc ->
      if valid_actor_id?(actor) do
        {:cont, acc}
      else
        {:halt, add_error(acc, :actors, "must all be handles or DIDs")}
      end
    end)
  end

  defp valid_actor_id?(actor) do
    is_binary(actor) && Regex.match?(~r/^(did:|@)/, actor)
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
         profiles = get_field(changeset, :profiles),
         {:ok, validated_list} <- validate_profile_list(profiles) do
      validated_output = apply_changes(changeset)
      {:ok, %{validated_output | profiles: Enum.reverse(validated_list)}}
    else
      %{valid?: false} = changeset -> {:error, changeset}
      error -> error
    end
  end

  defp validate_profile_list(profiles) do
    Enum.reduce_while(profiles, {:ok, []}, fn profile, {:ok, acc} ->
      case ProfileViewDetailed.validate(profile) do
        {:ok, validated_profile} -> {:cont, {:ok, [validated_profile | acc]}}
        error -> {:halt, error}
      end
    end)
  end
end
