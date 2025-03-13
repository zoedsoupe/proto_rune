defmodule Lexicon.Chat.Bsky.Convo.ConvoView do
  @moduledoc """
  View of a conversation.

  NSID: chat.bsky.convo.defs#convoView
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type last_message_type :: Lexicon.Chat.Bsky.Convo.MessageView.t() | Lexicon.Chat.Bsky.Convo.DeletedMessageView.t()
  @type t :: %__MODULE__{
          id: String.t(),
          rev: String.t(),
          members: [Lexicon.Chat.Bsky.Actor.ProfileViewBasic.t()],
          last_message: last_message_type | nil,
          muted: boolean(),
          opened: boolean() | nil,
          unread_count: integer()
        }

  @primary_key false
  embedded_schema do
    field :id, :string
    field :rev, :string
    # Array of chat.bsky.actor.defs#profileViewBasic
    field :members, {:array, :map}
    # Union of messageView or deletedMessageView
    field :last_message, :map
    field :muted, :boolean
    field :opened, :boolean
    field :unread_count, :integer
  end

  @doc """
  Creates a changeset for validating a conversation view.
  """
  def changeset(convo_view, attrs) do
    convo_view
    |> cast(attrs, [:id, :rev, :members, :last_message, :muted, :opened, :unread_count])
    |> validate_required([:id, :rev, :members, :muted, :unread_count])
    |> validate_members()
  end

  defp validate_members(changeset) do
    members = get_field(changeset, :members)

    if is_list(members) && Enum.empty?(members) do
      add_error(changeset, :members, "cannot be empty")
    else
      changeset
    end
  end

  @doc """
  Validates a conversation view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
