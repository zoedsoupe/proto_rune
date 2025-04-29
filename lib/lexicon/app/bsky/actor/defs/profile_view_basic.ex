defmodule Lexicon.App.Bsky.Actor.Defs.ProfileViewBasic do
  @moduledoc """
  Basic profile view with essential user information.

  Part of app.bsky.actor.defs lexicon.
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
          created_at: DateTime.t() | nil,
          verification: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :avatar, :string
    # Reference to #profileAssociated
    field :associated, :map
    # Reference to #viewerState
    field :viewer, :map
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    field :created_at, :utc_datetime
    # Reference to #verificationState
    field :verification, :map
  end

  @doc """
  Creates a changeset for validating a basic profile view.
  """
  def changeset(profile_view_basic, attrs) do
    profile_view_basic
    |> cast(attrs, [
      :did,
      :handle,
      :display_name,
      :avatar,
      :associated,
      :viewer,
      :labels,
      :created_at,
      :verification
    ])
    |> validate_required([:did, :handle])
    |> validate_length(:display_name, max: 640)
    |> validate_format(:did, ~r/^did:/, message: "must be a DID")
    |> validate_format(:handle, ~r/^[a-zA-Z0-9.-]+$/, message: "must be a valid handle")
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
