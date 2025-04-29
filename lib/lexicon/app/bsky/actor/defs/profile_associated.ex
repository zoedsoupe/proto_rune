defmodule Lexicon.App.Bsky.Actor.Defs.ProfileAssociated do
  @moduledoc """
  Information about an account's associated services.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          lists: integer() | nil,
          feedgens: integer() | nil,
          starter_packs: integer() | nil,
          labeler: boolean() | nil,
          chat: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :lists, :integer
    field :feedgens, :integer
    field :starter_packs, :integer
    field :labeler, :boolean
    # Reference to #profileAssociatedChat
    field :chat, :map
  end

  @doc """
  Creates a changeset for validating profile associated information.
  """
  def changeset(profile_associated, attrs) do
    cast(profile_associated, attrs, [:lists, :feedgens, :starter_packs, :labeler, :chat])
  end

  @doc """
  Validates profile associated information structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
