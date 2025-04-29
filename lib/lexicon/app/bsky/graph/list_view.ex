defmodule Lexicon.App.Bsky.Graph.ListView do
  @moduledoc """
  A detailed view of a list.

  Part of app.bsky.graph lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Graph, as: GraphDefs

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          creator: map(),
          name: String.t(),
          purpose: String.t(),
          description: String.t() | nil,
          description_facets: [map()] | nil,
          avatar: String.t() | nil,
          list_item_count: integer() | nil,
          labels: [map()] | nil,
          viewer: map() | nil,
          indexed_at: DateTime.t()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    # Reference to app.bsky.actor.defs#profileView
    field :creator, :map
    field :name, :string
    field :purpose, :string
    field :description, :string
    # Array of app.bsky.richtext.facet
    field :description_facets, {:array, :map}
    field :avatar, :string
    field :list_item_count, :integer
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Reference to #listViewerState
    field :viewer, :map
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a list view.
  """
  def changeset(list_view, attrs) do
    list_view
    |> cast(attrs, [
      :uri,
      :cid,
      :creator,
      :name,
      :purpose,
      :description,
      :description_facets,
      :avatar,
      :list_item_count,
      :labels,
      :viewer,
      :indexed_at
    ])
    |> validate_required([:uri, :cid, :creator, :name, :purpose, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_length(:name, min: 1, max: 64)
    |> validate_length(:description, max: 3000)
    |> validate_number(:list_item_count, greater_than_or_equal_to: 0)
    |> validate_list_purpose()
  end

  defp validate_list_purpose(changeset) do
    purpose = get_field(changeset, :purpose)

    if purpose && !GraphDefs.valid_list_purpose?(purpose) do
      add_error(changeset, :purpose, "must be a valid list purpose")
    else
      changeset
    end
  end

  @doc """
  Validates a list view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
