defmodule Lexicon.App.Bsky.Actor.ProfileAssociated do
  @moduledoc """
  Information about resources associated with a profile.

  NSID: app.bsky.actor.defs#profileAssociated
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor.ProfileAssociatedChat

  @type t :: %__MODULE__{
          lists: integer() | nil,
          feedgens: integer() | nil,
          starter_packs: integer() | nil,
          labeler: boolean() | nil,
          chat: ProfileAssociatedChat.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :lists, :integer
    field :feedgens, :integer
    field :starter_packs, :integer
    field :labeler, :boolean
    embeds_one :chat, ProfileAssociatedChat
  end

  @doc """
  Creates a changeset for validating profile associated information.
  """
  def changeset(profile_associated, attrs) do
    profile_associated
    |> cast(attrs, [:lists, :feedgens, :starter_packs, :labeler])
    |> cast_embed(:chat)
    |> validate_number(:lists, greater_than_or_equal_to: 0)
    |> validate_number(:feedgens, greater_than_or_equal_to: 0)
    |> validate_number(:starter_packs, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a profile associated structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
