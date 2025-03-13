defmodule Lexicon.App.Bsky.Actor.SearchActors do
  @moduledoc """
  Query to search for actors matching search criteria.

  NSID: app.bsky.actor.searchActors
  """

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.ProfileView

  @param_types %{
    term: :string,
    limit: :integer,
    cursor: :string
  }

  @output_types %{
    cursor: :string,
    # Array of ProfileView
    actors: {:array, :map}
  }

  @doc """
  Validates the parameters for searching actors.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:term])
    |> validate_length(:term, min: 1, max: 100)
    |> validate_number(:limit, greater_than: 0, less_than_or_equal_to: 100)
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from searching actors.
  """
  def validate_output(output) when is_map(output) do
    changeset =
      {%{}, @output_types}
      |> cast(output, Map.keys(@output_types))
      |> validate_required([:actors])

    case changeset do
      %{valid?: true} = changeset ->
        actors = get_field(changeset, :actors)

        # Validate each actor profile in the list
        validated_actors =
          Enum.reduce_while(actors, {:ok, []}, fn actor, {:ok, acc} ->
            case ProfileView.validate(actor) do
              {:ok, validated_actor} -> {:cont, {:ok, [validated_actor | acc]}}
              error -> {:halt, error}
            end
          end)

        case validated_actors do
          {:ok, validated_list} ->
            validated_output = apply_changes(changeset)
            {:ok, %{validated_output | actors: Enum.reverse(validated_list)}}

          error ->
            error
        end

      %{valid?: false} = changeset ->
        {:error, changeset}
    end
  end
end
