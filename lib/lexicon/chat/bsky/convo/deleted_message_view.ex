defmodule Lexicon.Chat.Bsky.Convo.DeletedMessageView do
  @moduledoc """
  View of a deleted chat message.

  NSID: chat.bsky.convo.defs#deletedMessageView
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Convo.MessageViewSender

  @type t :: %__MODULE__{
          id: String.t(),
          rev: String.t(),
          sender: MessageViewSender.t(),
          sent_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :id, :string
    field :rev, :string
    embeds_one :sender, MessageViewSender
    field :sent_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a deleted message view.
  """
  def changeset(deleted_message_view, attrs) do
    deleted_message_view
    |> cast(attrs, [:id, :rev, :sent_at])
    |> cast_embed(:sender)
    |> validate_required([:id, :rev, :sender, :sent_at])
  end

  @doc """
  Validates a deleted message view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
