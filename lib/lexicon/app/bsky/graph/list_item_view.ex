defmodule Lexicon.App.Bsky.Graph.ListItemView do
  @moduledoc """
  A view of a list item.

  Part of app.bsky.graph lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          uri: String.t(),
          subject: map()
        }

  @primary_key false
  embedded_schema do
    field :uri, :string
    # Reference to app.bsky.actor.defs#profileView
    field :subject, :map
  end

  @doc """
  Creates a changeset for validating a list item view.
  """
  def changeset(list_item_view, attrs) do
    list_item_view
    |> cast(attrs, [:uri, :subject])
    |> validate_required([:uri, :subject])
    |> validate_format(:uri, ~r/^at:\/\//, message: "must be an AT-URI")
  end

  @doc """
  Validates a list item view structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
