defmodule Lexicon.App.Bsky.Labeler.Defs.LabelerViewerState do
  @moduledoc """
  The viewer's state with respect to a labeler.

  Part of app.bsky.labeler.defs lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          like: String.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :like, :string
  end

  @doc """
  Creates a changeset for validating a labeler viewer state.
  """
  def changeset(viewer_state, attrs) do
    viewer_state
    |> cast(attrs, [:like])
    |> validate_format(:like, ~r/^at:\/\//, message: "must be an AT-URI")
  end

  @doc """
  Validates a labeler viewer state structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
