defmodule Lexicon.App.Bsky.Actor.Defs.ProfileView do
  @moduledoc """
  Standard profile view with most user information.

  Part of app.bsky.actor.defs lexicon.
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
          labels: [map()] | nil,
          verification: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :description, :string
    field :avatar, :string
    # Reference to #profileAssociated
    field :associated, :map
    field :indexed_at, :utc_datetime
    field :created_at, :utc_datetime
    # Reference to #viewerState
    field :viewer, :map
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Reference to #verificationState
    field :verification, :map
  end

  @doc """
  Creates a changeset for validating a profile view.
  """
  def changeset(profile_view, attrs) do
    profile_view
    |> cast(attrs, [
      :did,
      :handle,
      :display_name,
      :description,
      :avatar,
      :associated,
      :indexed_at,
      :created_at,
      :viewer,
      :labels,
      :verification
    ])
    |> validate_required([:did, :handle])
    |> validate_length(:display_name, max: 640)
    |> validate_length(:description, max: 2560)
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
    |> validate_format(:handle, ~r/^[a-zA-Z0-9.-]+$/, message: "must be a valid handle")
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
