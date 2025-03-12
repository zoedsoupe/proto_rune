defmodule Lexicon.App.Bsky.Actor.ProfileViewBasic do
  @moduledoc """
  Basic profile view of an actor.

  NSID: app.bsky.actor.defs#profileViewBasic
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
    created_at: DateTime.t() | nil
  }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :avatar, :string
    field :associated, :map # Reference to #profileAssociated
    field :viewer, :map # Reference to #viewerState
    field :labels, {:array, :map} # Reference to com.atproto.label.defs#label
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a basic profile view.
  """
  def changeset(profile_view, attrs) do
    profile_view
    |> cast(attrs, [:did, :handle, :display_name, :avatar, :associated, :viewer, :labels, :created_at])
    |> validate_required([:did, :handle])
    |> validate_format(:did, ~r/^did:/)
    |> validate_length(:display_name, max: 640)
  end

  @doc """
  Validates a basic profile view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end