defmodule Lexicon.App.Bsky.Notification do
  @moduledoc """
  Definitions for notification-related data structures.

  NSID: app.bsky.notification
  """

  alias Lexicon.App.Bsky.Notification.RecordDeleted

  @doc """
  Validates a record deleted structure.
  """
  def validate_record_deleted(data) when is_map(data) do
    RecordDeleted.validate(data)
  end
end
