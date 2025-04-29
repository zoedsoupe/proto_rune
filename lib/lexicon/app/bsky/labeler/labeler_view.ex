defmodule Lexicon.App.Bsky.Labeler.LabelerView do
  @moduledoc """
  A view of a labeler service.

  Part of app.bsky.labeler lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          creator: map(),
          like_count: integer() | nil,
          viewer: map() | nil,
          indexed_at: DateTime.t(),
          labels: [map()] | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    # Reference to app.bsky.actor.defs#profileView
    field :creator, :map
    field :like_count, :integer
    # Reference to #labelerViewerState
    field :viewer, :map
    field :indexed_at, :utc_datetime
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
  end

  @doc """
  Creates a changeset for validating a labeler view.
  """
  def changeset(labeler_view, attrs) do
    labeler_view
    |> cast(attrs, [:uri, :cid, :creator, :like_count, :viewer, :indexed_at, :labels])
    |> validate_required([:uri, :cid, :creator, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_number(:like_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a labeler view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
