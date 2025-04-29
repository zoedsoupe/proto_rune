defmodule Lexicon.App.Bsky.Feed.ThreadgateView do
  @moduledoc """
  A view of a threadgate, which controls who can reply to a post.

  Part of app.bsky.feed lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t() | nil,
          cid: String.t() | nil,
          record: map() | nil,
          lists: [map()] | nil
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    field :cid, :string
    field :record, :map
    # Array of app.bsky.graph.defs#listViewBasic
    field :lists, {:array, :map}
  end

  @doc """
  Creates a changeset for validating a threadgate view.
  """
  def changeset(threadgate_view, attrs) do
    cast(threadgate_view, attrs, [:uri, :cid, :record, :lists])
  end

  @doc """
  Validates a threadgate view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
