defmodule Lexicon.Chat.Bsky.Convo.MessageInput do
  @moduledoc """
  Input for sending a new message.

  NSID: chat.bsky.convo.defs#messageInput
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          text: String.t(),
          facets: [map()] | nil,
          embed: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :text, :string
    # Reference to app.bsky.richtext.facet
    field :facets, {:array, :map}
    # Union of app.bsky.embed.record
    field :embed, :map
  end

  @doc """
  Creates a changeset for validating a message input.
  """
  def changeset(message_input, attrs) do
    message_input
    |> cast(attrs, [:text, :facets, :embed])
    |> validate_required([:text])
    |> validate_length(:text, max: 10_000)
  end

  @doc """
  Validates a message input structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
