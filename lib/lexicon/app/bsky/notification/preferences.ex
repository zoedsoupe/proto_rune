defmodule Lexicon.App.Bsky.Notification.Preferences do
  @moduledoc """
  Represents notification-related preferences for an account.

  NSID: app.bsky.notification.putPreferences
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          priority: boolean()
        }

  @primary_key false
  embedded_schema do
    field :priority, :boolean
  end

  @doc """
  Creates a changeset for validating notification preferences.
  """
  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [:priority])
    |> validate_required([:priority])
  end

  @doc """
  Creates new notification preferences with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates new notification preferences, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, preferences} -> preferences
      {:error, changeset} -> raise "Invalid notification preferences: #{inspect(changeset.errors)}"
    end
  end
end
