defmodule Lexicon.Chat.Bsky.Convo.MessageView do
  @moduledoc """
  View of a chat message.

  NSID: chat.bsky.convo.defs#messageView
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.Chat.Bsky.Convo.MessageViewSender

  @type t :: %__MODULE__{
          id: String.t(),
          rev: String.t(),
          text: String.t(),
          facets: [map()] | nil,
          embed: map() | nil,
          sender: MessageViewSender.t(),
          sent_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :id, :string
    field :rev, :string
    field :text, :string
    # Reference to app.bsky.richtext.facet
    field :facets, {:array, :map}
    # Union of app.bsky.embed.record#view
    field :embed, :map
    embeds_one :sender, MessageViewSender
    field :sent_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a message view.
  """
  def changeset(message_view, attrs) do
    message_view
    |> cast(attrs, [:id, :rev, :text, :facets, :embed, :sent_at])
    |> cast_embed(:sender)
    |> validate_required([:id, :rev, :text, :sender, :sent_at])
    |> validate_length(:text, max: 10_000)
  end

  @doc """
  Validates a message view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
