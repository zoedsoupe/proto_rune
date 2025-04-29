defmodule Lexicon.App.Bsky.Graph.Defs.ListViewBasic do
  @moduledoc """
  A basic view of a list.

  Part of app.bsky.graph.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Lexicon.App.Bsky.Graph.Defs

  @type t :: %__MODULE__{
          uri: String.t(),
          cid: String.t(),
          name: String.t(),
          purpose: String.t(),
          avatar: String.t() | nil,
          list_item_count: integer() | nil,
          labels: [map()] | nil,
          viewer: map() | nil,
          indexed_at: DateTime.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    field :name, :string
    field :purpose, :string
    field :avatar, :string
    field :list_item_count, :integer
    # Array of com.atproto.label.defs#label
    field :labels, {:array, :map}
    # Reference to #listViewerState
    field :viewer, :map
    field :indexed_at, :utc_datetime
  end

  @doc """
  Creates a changeset for validating a basic list view.
  """
  def changeset(list_view, attrs) do
    list_view
    |> cast(attrs, [
      :uri,
      :cid,
      :name,
      :purpose,
      :avatar,
      :list_item_count,
      :labels,
      :viewer,
      :indexed_at
    ])
    |> validate_required([:uri, :cid, :name, :purpose])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
    |> validate_length(:name, min: 1, max: 64)
    |> validate_number(:list_item_count, greater_than_or_equal_to: 0)
    |> validate_list_purpose()
  end

  defp validate_list_purpose(changeset) do
    purpose = get_field(changeset, :purpose)

    if purpose && !Defs.valid_list_purpose?(purpose) do
      add_error(changeset, :purpose, "must be a valid list purpose")
    else
      changeset
    end
  end

  @doc """
  Validates a basic list view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
