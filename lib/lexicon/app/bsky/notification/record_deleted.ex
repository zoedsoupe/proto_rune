defmodule Lexicon.App.Bsky.Notification.RecordDeleted do
  @moduledoc """
  Marker for a deleted record.

  Part of app.bsky.notification lexicon.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    # This schema intentionally has no fields
  end

  @doc """
  Creates a changeset for validating a record deleted marker.
  """
  def changeset(record_deleted, attrs) do
    cast(record_deleted, attrs, [])
  end

  @doc """
  Validates a record deleted marker structure.
  """
  def validate(data) when is_map(data) do
    %__MODULE__{}
    |> changeset(data)
    |> apply_action(:validate)
  end
end
