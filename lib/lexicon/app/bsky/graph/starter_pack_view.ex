defmodule Lexicon.App.Bsky.Graph.StarterPackView do
  @moduledoc """
  A view of a starter pack.

  Part of app.bsky.graph lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Graph.ListItemView
  alias Lexicon.App.Bsky.Graph.ListViewBasic

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          record: map(),
          creator: map(),
          list: map() | nil,
          list_items_sample: [map()] | nil,
          feeds: [map()] | nil,
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
    # Reference to #listViewBasic
    embeds_one :list, ListViewBasic
    # Array of #listItemView
    embeds_many :list_items_sample, ListItemView
    # Array of app.bsky.feed.defs#generatorView
    field :feeds, {:array, :map}
    field :joined_week_count, :integer
    field :joined_all_time_count, :integer
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a starter pack view.
  """
  def changeset(starter_pack_view, attrs) do
    starter_pack_view
    |> cast(attrs, [
      :uri,
      :cid,
      :record,
      :creator,
      :feeds,
      :joined_week_count,
      :joined_all_time_count,
      :labels,
      :indexed_at
    ])
    |> cast_embed(:list)
    |> cast_embed(:list_items_sample)
    |> validate_required([:uri, :cid, :record, :creator, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_length(:list_items_sample, max: 12)
    |> validate_length(:feeds, max: 3)
    |> validate_number(:joined_week_count, greater_than_or_equal_to: 0)
    |> validate_number(:joined_all_time_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Validates a starter pack view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
