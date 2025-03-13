defmodule Lexicon.App.Bsky.Graph.ListViewerState do
  @moduledoc """
  Viewer state related to a list, indicating if the user has muted or blocked the list.

  NSID: app.bsky.graph.defs#listViewerState
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
  def changeset(viewer_state, attrs) do
    viewer_state
    |> cast(attrs, [:muted, :blocked])
    |> validate_blocked()
  end

  defp validate_blocked(changeset) do
    if blocked = get_field(changeset, :blocked) do
      if is_binary(blocked) do
        if String.match?(blocked, ~r/^at:\/\//) do
          changeset
        else
          add_error(changeset, :blocked, "must be an AT-URI")
        end
      else
        add_error(changeset, :blocked, "must be a string")
      end
    else
      changeset
    end
  end

  @doc """
  Creates a new list viewer state with the given attributes.
  """
  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc """
  Creates a new list viewer state, raising an error if validation fails.
  """
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, viewer_state} -> viewer_state
      {:error, changeset} -> raise "Invalid list viewer state: #{inspect(changeset.errors)}"
    end
  end
end
