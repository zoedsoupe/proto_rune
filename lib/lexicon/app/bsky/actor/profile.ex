defmodule Lexicon.App.Bsky.Actor.Profile do
  @moduledoc """
  A declaration of a Bluesky account profile.

  NSID: app.bsky.actor.profile
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          display_name: String.t() | nil,
          description: String.t() | nil,
          # blob
          avatar: map() | nil,
          # blob
          banner: map() | nil,
          labels: map() | nil,
          joined_via_starter_pack: map() | nil,
          pinned_post: map() | nil,
          created_at: DateTime.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :display_name, :string
    field :description, :string
    # blob
    field :avatar, :map
    # blob
    field :banner, :map
    # union
    field :labels, :map
    # Reference to com.atproto.repo.strongRef
    field :joined_via_starter_pack, :map
    # Reference to com.atproto.repo.strongRef
    field :pinned_post, :map
    field :created_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a profile.
  """
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :display_name,
      :description,
      :avatar,
      :banner,
      :labels,
      :joined_via_starter_pack,
      :pinned_post,
      :created_at
    ])
    |> validate_length(:display_name, max: 640)
    |> validate_length(:description, max: 2560)
    |> validate_blob(:avatar)
    |> validate_blob(:banner)
  end

  defp validate_blob(changeset, field) do
    if blob = get_change(changeset, field) do
      # Check blob data format - simplified for now
      # In a real implementation, this would validate MIME types, size, etc.
      if is_map(blob) and is_binary(Map.get(blob, :data)) do
        changeset
      else
        add_error(changeset, field, "invalid blob format")
      end
    else
      changeset
    end
  end

  @doc """
  Creates a new profile with the given attributes.
  """
  def new(attrs \\ %{}) do
    attrs = Map.put_new_lazy(attrs, :created_at, &DateTime.utc_now/0)

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Validates a profile structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
