defmodule Lexicon.Chat.Bsky.Convo.LogCreateMessage do
  @moduledoc """
  Log entry for creating a message in a conversation.

  NSID: chat.bsky.convo.defs#logCreateMessage
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type message_type :: Lexicon.Chat.Bsky.Convo.MessageView.t() | Lexicon.Chat.Bsky.Convo.DeletedMessageView.t()
  @type t :: %__MODULE__{
    rev: String.t(),
    convo_id: String.t(),
    message: message_type
  }

  @primary_key false
  embedded_schema do
    field :rev, :string
    field :convo_id, :string
    field :message, :map # Union of messageView or deletedMessageView
  end

  @doc """
  Creates a changeset for validating a log create message entry.
  """
  def changeset(log_entry, attrs) do
    log_entry
    |> cast(attrs, [:rev, :convo_id, :message])
    |> validate_required([:rev, :convo_id, :message])
  end

  @doc """
  Validates a log create message entry structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end