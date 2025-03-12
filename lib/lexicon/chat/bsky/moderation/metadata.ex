defmodule Lexicon.Chat.Bsky.Moderation.Metadata do
  @moduledoc """
  Actor metadata used for moderation.

  NSID: chat.bsky.moderation.getActorMetadata#metadata
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    messages_sent: integer(),
    messages_received: integer(),
    convos: integer(),
    convos_started: integer()
  }

  @primary_key false
  embedded_schema do
    field :messages_sent, :integer
    field :messages_received, :integer
    field :convos, :integer
    field :convos_started, :integer
  end

  @doc """
  Creates a changeset for validating metadata.
  """
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:messages_sent, :messages_received, :convos, :convos_started])
    |> validate_required([:messages_sent, :messages_received, :convos, :convos_started])
    |> validate_number(:messages_sent, greater_than_or_equal_to: 0)
    |> validate_number(:messages_received, greater_than_or_equal_to: 0)
    |> validate_number(:convos, greater_than_or_equal_to: 0)
    |> validate_number(:convos_started, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a metadata structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end