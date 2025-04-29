defmodule Lexicon.App.Bsky.Graph.Defs.ListViewerState do
  @moduledoc """
  The state of the list from the viewer's perspective.

  Part of app.bsky.graph.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          muted: boolean() | nil,
          blocked: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :muted, :boolean
    field :blocked, :string
  end

  @doc """
  Creates a changeset for validating a list viewer state.
  """
  def changeset(list_viewer_state, attrs) do
    list_viewer_state
    |> cast(attrs, [:muted, :blocked])
    |> validate_format(:blocked, ~r/^at:\/\//, message: "must be an AT-URI")
  end

  @doc """
  Validates a list viewer state structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
