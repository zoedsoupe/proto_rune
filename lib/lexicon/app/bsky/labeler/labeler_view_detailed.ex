defmodule Lexicon.App.Bsky.Labeler.LabelerViewDetailed do
  @moduledoc """
  A detailed view of a labeler service.

  Part of app.bsky.labeler lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Labeler.LabelerPolicies

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          creator: map(),
          policies: map(),
          like_count: integer() | nil,
          viewer: map() | nil,
          indexed_at: DateTime.t(),
          labels: [map()] | nil,
          reason_types: [String.t()] | nil,
          subject_types: [String.t()] | nil,
          subject_collections: [String.t()] | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    # Reference to app.bsky.actor.defs#profileView
    field :creator, :map
    # Reference to #labelerPolicies
    embeds_one :policies, LabelerPolicies
    field :like_count, :integer
    # Reference to #labelerViewerState
    field :viewer, :map
    field :indexed_at, :utc_datetime
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Array of com.atproto.moderation.defs#reasonType
    field :reason_types, {:array, :string}
    # Array of com.atproto.moderation.defs#subjectType
    field :subject_types, {:array, :string}
    field :subject_collections, {:array, :string}
  end

  @doc """
  Creates a changeset for validating a detailed labeler view.
  """
  def changeset(labeler_view, attrs) do
    labeler_view
    |> cast(attrs, [
      :uri,
      :cid,
      :creator,
      :like_count,
      :viewer,
      :indexed_at,
      :labels,
      :reason_types,
      :subject_types,
      :subject_collections
    ])
    |> cast_embed(:policies, required: true)
    |> validate_required([:uri, :cid, :creator, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_number(:like_count, greater_than_or_equal_to: 0)
    |> validate_nsids(:subject_collections)
  end

  defp validate_nsids(changeset, field) do
    collections = get_field(changeset, field)

    if collections do
      # Validate each NSID in the array
      invalid_nsids =
        Enum.filter(collections, fn nsid ->
          !String.match?(nsid, ~r/^[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+$/)
        end)

      if Enum.empty?(invalid_nsids) do
        changeset
      else
        add_error(changeset, field, "contains invalid NSIDs")
      end
    else
      changeset
    end
  end

  @doc """
  Validates a detailed labeler view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
