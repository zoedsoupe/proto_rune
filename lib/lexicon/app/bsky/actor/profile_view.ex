defmodule Lexicon.App.Bsky.Actor.ProfileView do
  @moduledoc """
  Standard profile view of an actor.

  NSID: app.bsky.actor.defs#profileView
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    did: String.t(),
    handle: String.t(),
    display_name: String.t() | nil,
    description: String.t() | nil,
    avatar: String.t() | nil,
    associated: map() | nil,
    indexed_at: DateTime.t() | nil,
    created_at: DateTime.t() | nil,
    viewer: map() | nil,
    labels: [map()] | nil
  }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :description, :string
    field :avatar, :string
    field :associated, :map # Reference to #profileAssociated
    field :indexed_at, :utc_datetime
    field :created_at, :utc_datetime
    field :viewer, :map # Reference to #viewerState
    field :labels, {:array, :map} # Reference to com.atproto.label.defs#label
  end

  @doc """
  Creates a changeset for validating a profile view.
  """
  def changeset(profile_view, attrs) do
    profile_view
    |> cast(attrs, [:did, :handle, :display_name, :description, :avatar, :associated, 
                   :indexed_at, :created_at, :viewer, :labels])
    |> validate_required([:did, :handle])
    |> validate_format(:did, ~r/^did:/)
    |> validate_length(:display_name, max: 640)
    |> validate_length(:description, max: 2560)
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