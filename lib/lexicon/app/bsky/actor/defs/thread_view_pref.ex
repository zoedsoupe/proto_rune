defmodule Lexicon.App.Bsky.Actor.Defs.ThreadViewPref do
  @moduledoc """
  Preferences for thread view.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.Defs

  @type t :: %__MODULE__{
          sort: String.t() | nil,
          prioritize_followed_users: boolean() | nil
        }

  @primary_key false
  embedded_schema do
    field :sort, :string
    field :prioritize_followed_users, :boolean
  end

  @doc """
  Creates a changeset for validating thread view preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:sort, :prioritize_followed_users])
    |> validate_thread_sort()
  end

  defp validate_thread_sort(changeset) do
    sort = get_field(changeset, :sort)

    if sort && !Defs.valid_thread_sort?(sort) do
      add_error(changeset, :sort, "must be a valid sort value")
    else
      changeset
    end
  end

  @doc """
  Validates a thread view preferences structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
