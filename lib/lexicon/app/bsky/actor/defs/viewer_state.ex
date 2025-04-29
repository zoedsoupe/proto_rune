defmodule Lexicon.App.Bsky.Actor.Defs.ViewerState do
  @moduledoc """
  Metadata about the requesting account's relationship with the subject account.

  Part of app.bsky.actor.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          muted: boolean() | nil,
          muted_by_list: map() | nil,
          blocked_by: boolean() | nil,
          blocking: String.t() | nil,
          blocking_by_list: map() | nil,
          following: String.t() | nil,
          followed_by: String.t() | nil,
          known_followers: map() | nil
        }

  @primary_key false
  embedded_schema do
    field :muted, :boolean
    # Reference to app.bsky.graph.defs#listViewBasic
    field :muted_by_list, :map
    field :blocked_by, :boolean
    field :blocking, :string
    # Reference to app.bsky.graph.defs#listViewBasic
    field :blocking_by_list, :map
    field :following, :string
    field :followed_by, :string
    # Reference to #knownFollowers
    field :known_followers, :map
  end

  @doc """
  Creates a changeset for validating viewer state information.
  """
  def changeset(viewer_state, attrs) do
    viewer_state
    |> cast(attrs, [
      :muted,
      :muted_by_list,
      :blocked_by,
      :blocking,
      :blocking_by_list,
      :following,
      :followed_by,
      :known_followers
    ])
    |> validate_format(:blocking, ~r/^at:\/\//, message: "must be an AT URI")
    |> validate_format(:following, ~r/^at:\/\//, message: "must be an AT URI")
    |> validate_format(:followed_by, ~r/^at:\/\//, message: "must be an AT URI")
  end

  @doc """
  Validates viewer state information structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
