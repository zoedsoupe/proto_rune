defmodule Lexicon.App.Bsky.Actor.ContentLabelPref do
  @moduledoc """
  Preference for content label visibility.

  Part of app.bsky.actor lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Actor, as: ActorDefs

  @type t :: %__MODULE__{
          labeler_did: String.t() | nil,
          label: String.t(),
          visibility: String.t()
        }

  @primary_key false
  embedded_schema do
    field :labeler_did, :string
    field :label, :string
    field :visibility, :string
  end

  @doc """
  Creates a changeset for validating content label preferences.
  """
  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:labeler_did, :label, :visibility])
    |> validate_required([:label, :visibility])
    |> validate_content_visibility()
    |> validate_format(:labeler_did, ~r/^did:/, message: "must be a DID")
  end

  defp validate_content_visibility(changeset) do
    visibility = get_field(changeset, :visibility)

    if visibility && !ActorDefs.valid_content_visibility?(visibility) do
      add_error(changeset, :visibility, "must be a valid visibility value")
    else
      changeset
    end
  end

  @doc """
  Validates a content label preference structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
