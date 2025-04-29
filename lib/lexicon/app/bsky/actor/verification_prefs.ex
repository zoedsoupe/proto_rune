defmodule Lexicon.App.Bsky.Actor.VerificationPrefs do
  @moduledoc """
  Preferences for how verified accounts appear in the app.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          hide_badges: boolean() | nil
        }

  @primary_key false
  embedded_schema do
    field :hide_badges, :boolean, default: false
  end

  @doc """
  Creates a changeset for validating verification preferences.
  """
  def changeset(pref, attrs) do
    cast(pref, attrs, [:hide_badges])
  end

  @doc """
  Validates a verification preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
