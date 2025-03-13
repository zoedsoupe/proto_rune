defmodule Lexicon.Chat.Bsky.Convo.MessageViewSender do
  @moduledoc """
  Sender information for a message view.

  NSID: chat.bsky.convo.defs#messageViewSender
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t()
        }

  @primary_key false
  embedded_schema do
    field :did, :string
  end

  @doc """
  Creates a changeset for validating a message view sender.
  """
  def changeset(sender, attrs) do
    sender
    |> cast(attrs, [:did])
    |> validate_required([:did])
    |> validate_format(:did, ~r/^did:/)
  end

  @doc """
  Validates a message view sender structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
