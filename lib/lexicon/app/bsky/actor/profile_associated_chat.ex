defmodule Lexicon.App.Bsky.Actor.ProfileAssociatedChat do
  @moduledoc """
  Information about chat settings associated with a profile.

  NSID: app.bsky.actor.defs#profileAssociatedChat
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type allow_incoming_option :: :all | :none | :following
  @type t :: %__MODULE__{
    allow_incoming: allow_incoming_option()
  }

  @primary_key false
  embedded_schema do
    field :allow_incoming, Ecto.Enum, values: [:all, :none, :following]
  end

  @doc """
  Creates a changeset for validating profile associated chat information.
  """
  def changeset(profile_associated_chat, attrs) do
    profile_associated_chat
    |> cast(attrs, [:allow_incoming])
    |> validate_required([:allow_incoming])
  end

  @doc """
  Validates a profile associated chat structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end