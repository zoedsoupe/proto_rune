defmodule Lexicon.App.Bsky.Actor.Defs.ProfileAssociatedChat do
  @moduledoc """
  Information about an account's chat preferences.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.Defs

  @type t :: %__MODULE__{
          allow_incoming: String.t()
        }

  @primary_key false
  embedded_schema do
    field :allow_incoming, :string
  end

  @doc """
  Creates a changeset for validating profile associated chat information.
  """
  def changeset(profile_associated_chat, attrs) do
    profile_associated_chat
    |> cast(attrs, [:allow_incoming])
    |> validate_required([:allow_incoming])
    |> validate_allow_incoming()
  end

  defp validate_allow_incoming(changeset) do
    value = get_field(changeset, :allow_incoming)

    if is_nil(value) or Defs.valid_chat_allow_incoming?(value) do
      changeset
    else
      add_error(changeset, :allow_incoming, "has invalid value")
    end
  end

  @doc """
  Validates profile associated chat information structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
