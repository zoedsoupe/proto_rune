defmodule Lexicon.Chat.Bsky.Convo.MessageRef do
  @moduledoc """
  Reference to a specific message in a conversation.

  NSID: chat.bsky.convo.defs#messageRef
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    did: String.t(),
    convo_id: String.t(),
    message_id: String.t()
  }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :convo_id, :string
    field :message_id, :string
  end

  @doc """
  Creates a changeset for validating a message reference.
  """
  def changeset(message_ref, attrs) do
    message_ref
    |> cast(attrs, [:did, :convo_id, :message_id])
    |> validate_required([:did, :convo_id, :message_id])
    |> validate_format(:did, ~r/^did:/)
  end

  @doc """
  Validates a message reference structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end