defmodule Lexicon.App.Bsky.Actor.AdultContentPref do
  @moduledoc """
  Preference for adult content visibility.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          enabled: boolean()
        }

  @primary_key false
  embedded_schema do
    field :enabled, :boolean, default: false
  end

  @doc """
  Creates a changeset for validating adult content preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:enabled])
    |> validate_required([:enabled])
  end

  @doc """
  Validates an adult content preference structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
