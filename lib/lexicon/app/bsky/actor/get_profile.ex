defmodule Lexicon.App.Bsky.Actor.GetProfile do
  @moduledoc """
  Query to get detailed profile view of an actor.

  NSID: app.bsky.actor.getProfile
  """

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.ProfileViewDetailed

  @param_types %{
    actor: :string
  }

  @doc """
  Validates the parameters for getting a profile.
  """
  def validate_params(params) when is_map(params) do
    {%{}, @param_types}
    |> cast(params, Map.keys(@param_types))
    |> validate_required([:actor])
    |> validate_format(:actor, ~r/^(did:|@)/, message: "must be a handle or DID")
    |> apply_action(:validate)
  end

  @doc """
  Validates the output from getting a profile.
  """
  def validate_output(output) when is_map(output) do
    ProfileViewDetailed.validate(output)
  end
end