defmodule Lexicon.App.Bsky.Feed.GeneratorViewerState do
  @moduledoc """
  The state of the generator from the viewer's perspective.

  Part of app.bsky.feed lexicon.
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
  Creates a changeset for validating a generator viewer state.
  """
  def changeset(generator_viewer_state, attrs) do
    cast(generator_viewer_state, attrs, [:like])
  end

  @doc """
  Validates a generator viewer state structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
