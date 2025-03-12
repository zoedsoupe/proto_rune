defmodule Lexicon.App.Bsky.Actor.ProfileViewDetailed do
  @moduledoc """
  Detailed profile view of an actor with additional stats.

  NSID: app.bsky.actor.defs#profileViewDetailed
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    did: String.t(),
    handle: String.t(),
    display_name: String.t() | nil,
    description: String.t() | nil,
    avatar: String.t() | nil,
    banner: String.t() | nil,
    followers_count: integer() | nil,
    follows_count: integer() | nil,
    posts_count: integer() | nil,
    associated: map() | nil,
    joined_via_starter_pack: map() | nil,
    indexed_at: DateTime.t() | nil,
    created_at: DateTime.t() | nil,
    viewer: map() | nil,
    labels: [map()] | nil,
    pinned_post: map() | nil
  }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :description, :string
    field :avatar, :string
    field :banner, :string
    field :followers_count, :integer
    field :follows_count, :integer
    field :posts_count, :integer
    field :associated, :map # Reference to #profileAssociated
    field :joined_via_starter_pack, :map # Reference to app.bsky.graph.defs#starterPackViewBasic
    field :indexed_at, :utc_datetime
    field :created_at, :utc_datetime
    field :viewer, :map # Reference to #viewerState
    field :labels, {:array, :map} # Reference to com.atproto.label.defs#label
    field :pinned_post, :map # Reference to com.atproto.repo.strongRef
  end

  @doc """
  Creates a changeset for validating a detailed profile view.
  """
  def changeset(profile_view, attrs) do
    profile_view
    |> cast(attrs, [:did, :handle, :display_name, :description, :avatar, :banner, 
                   :followers_count, :follows_count, :posts_count, :associated,
                   :joined_via_starter_pack, :indexed_at, :created_at, :viewer, 
                   :labels, :pinned_post])
    |> validate_required([:did, :handle])
    |> validate_format(:did, ~r/^did:/)
    |> validate_length(:display_name, max: 640)
    |> validate_length(:description, max: 2560)
    |> validate_number(:followers_count, greater_than_or_equal_to: 0)
    |> validate_number(:follows_count, greater_than_or_equal_to: 0)
    |> validate_number(:posts_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a detailed profile view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end