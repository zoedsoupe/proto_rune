defmodule Lexicon.App.Bsky.Labeler.LabelViewerState do
  @moduledoc """
  The state of a labeler from the perspective of the viewer.

  NSID: app.bsky.labeler.defs#labelerViewerState
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
  def changeset(labeler_viewer_state, attrs) do
    labeler_viewer_state
    |> cast(attrs, [:like])
    |> validate_format(:like, ~r/^at:\/\//, message: "must be a valid AT-URI", allow_blank: true, allow_nil: true)
  end

  @doc """
  Creates a new labeler viewer state with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new labeler viewer state, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, labeler_viewer_state} -> labeler_viewer_state
      {:error, changeset} -> raise "Invalid labeler viewer state: #{inspect(changeset.errors)}"
    end
  end
end
