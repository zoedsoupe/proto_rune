defmodule Lexicon.App.Bsky.Feed.ReasonPin do
  @moduledoc """
  Information about why a post is in the feed (pinned).

  NSID: app.bsky.feed.defs#reasonPin
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          # This type has no properties in the lexicon
        }

  @primary_key false
  embedded_schema do
    # No fields
  end

  @doc """
  Creates a changeset for validating a pin reason.
  """
  def changeset(reason_pin, _attrs) do
    # No fields to validate
    change(reason_pin)
  end

  @doc """
  Validates a pin reason structure.
  """
  def validate(_data) do
    {:ok, %__MODULE__{}}
  end
end
