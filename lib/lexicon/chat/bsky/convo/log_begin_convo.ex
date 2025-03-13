defmodule Lexicon.Chat.Bsky.Convo.LogBeginConvo do
  @moduledoc """
  Log entry for beginning a conversation.

  NSID: chat.bsky.convo.defs#logBeginConvo
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          rev: String.t(),
          convo_id: String.t()
        }

  @primary_key false
  embedded_schema do
    field :rev, :string
    field :convo_id, :string
  end

  @doc """
  Creates a changeset for validating a log begin conversation entry.
  """
  def changeset(log_entry, attrs) do
    log_entry
    |> cast(attrs, [:rev, :convo_id])
    |> validate_required([:rev, :convo_id])
  end

  @doc """
  Validates a log begin conversation entry structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
