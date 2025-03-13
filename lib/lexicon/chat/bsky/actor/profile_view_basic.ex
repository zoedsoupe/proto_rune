defmodule Lexicon.Chat.Bsky.Actor.ProfileViewBasic do
  @moduledoc """
  Basic profile view with chat-specific fields.

  NSID: chat.bsky.actor.defs#profileViewBasic
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          display_name: String.t() | nil,
          avatar: String.t() | nil,
          associated: map() | nil,
          viewer: map() | nil,
          labels: [map()] | nil,
          chat_disabled: boolean() | nil
        }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :avatar, :string
    # Reference to app.bsky.actor.defs#profileAssociated
    field :associated, :map
    # Reference to app.bsky.actor.defs#viewerState
    field :viewer, :map
    # Reference to com.atproto.label.defs#label
    field :labels, {:array, :map}
    field :chat_disabled, :boolean
  end

  @doc """
  Creates a changeset for validating the profile view.
  """
  def changeset(profile_view, attrs) do
    profile_view
    |> cast(attrs, [:did, :handle, :display_name, :avatar, :associated, :viewer, :labels, :chat_disabled])
    |> validate_required([:did, :handle])
    |> validate_format(:did, ~r/^did:/)
    |> validate_length(:display_name, max: 64)
  end

  @doc """
  Validates a profile view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
