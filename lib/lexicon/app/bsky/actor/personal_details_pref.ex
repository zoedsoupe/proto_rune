defmodule Lexicon.App.Bsky.Actor.PersonalDetailsPref do
  @moduledoc """
  Preferences for personal details.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          birth_date: DateTime.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :birth_date, :utc_datetime
  end

  @doc """
  Creates a changeset for validating personal details preferences.
  """
  def changeset(pref, attrs) do
    cast(pref, attrs, [:birth_date])
  end

  @doc """
  Validates a personal details preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
