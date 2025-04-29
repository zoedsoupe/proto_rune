defmodule Lexicon.App.Bsky.Graph.Defs.StarterPackViewBasic do
  @moduledoc """
  A basic view of a starter pack.

  Part of app.bsky.graph.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          record: map(),
          creator: map(),
          list_item_count: integer() | nil,
          joined_week_count: integer() | nil,
          joined_all_time_count: integer() | nil,
          labels: [map()] | nil,
          indexed_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    field :record, :map
    # Reference to app.bsky.actor.defs#profileViewBasic
    field :creator, :map
    field :list_item_count, :integer
    field :joined_week_count, :integer
    field :joined_all_time_count, :integer
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a basic starter pack view.
  """
  def changeset(starter_pack_view, attrs) do
    starter_pack_view
    |> cast(attrs, [
      :uri,
      :cid,
      :record,
      :creator,
      :list_item_count,
      :joined_week_count,
      :joined_all_time_count,
      :labels,
      :indexed_at
    ])
    |> validate_required([:uri, :cid, :record, :creator, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_number(:list_item_count, greater_than_or_equal_to: 0)
    |> validate_number(:joined_week_count, greater_than_or_equal_to: 0)
    |> validate_number(:joined_all_time_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a basic starter pack view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
