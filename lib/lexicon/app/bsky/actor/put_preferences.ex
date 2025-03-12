defmodule Lexicon.App.Bsky.Actor.PutPreferences do
  @moduledoc """
  Procedure to update account preferences.

  NSID: app.bsky.actor.putPreferences
  """

  import Ecto.Changeset

  @input_types %{
    preferences: {:array, :map}
  }

  @doc """
  Validates the input for putting preferences.
  """
  def validate_input(input) when is_map(input) do
    changeset = 
      {%{}, @input_types}
      |> cast(input, Map.keys(@input_types))
      |> validate_required([:preferences])

    if prefs = get_field(changeset, :preferences) do
      if is_list(prefs) && !Enum.empty?(prefs) do
        apply_action(changeset, :validate)
      else
        add_error(changeset, :preferences, "cannot be empty")
        |> apply_action(:validate)
      end
    else
      apply_action(changeset, :validate)
    end
  end

  @doc """
  This procedure has no output.
  """
  def validate_output(nil), do: {:ok, nil}
  def validate_output(_), do: {:ok, nil}
end