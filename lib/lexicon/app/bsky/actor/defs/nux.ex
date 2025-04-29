defmodule Lexicon.App.Bsky.Actor.Defs.Nux do
  @moduledoc """
  A new user experience (NUX) storage object.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t(),
          completed: boolean(),
          data: String.t() | nil,
          expires_at: DateTime.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :id, :string
    field :completed, :boolean, default: false
    field :data, :string
    field :expires_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a NUX object.
  """
  def changeset(nux, attrs) do
    nux
    |> cast(attrs, [:id, :completed, :data, :expires_at])
    |> validate_required([:id, :completed])
    |> validate_length(:id, max: 100)
    |> validate_length(:data, max: 3000)
  end

  @doc """
  Validates a NUX object structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
