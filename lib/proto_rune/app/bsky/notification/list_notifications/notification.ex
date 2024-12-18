# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Notification.ListNotifications.Notification do
  @moduledoc """
  Generated schema for notification

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :author, :reason, :record, :is_read, :indexed_at]
  defstruct author: nil,
            cid: nil,
            indexed_at: nil,
            is_read: nil,
            labels: nil,
            reason: nil,
            reason_subject: nil,
            record: nil,
            uri: nil

  @type t :: %__MODULE__{
          author: ProtoRune.App.Bsky.Actor.Defs.ProfileView.t(),
          cid: String.t(),
          indexed_at: String.t(),
          is_read: boolean(),
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          reason: :like | :repost | :follow | :mention | :reply | :quote | :"starterpack-joined",
          reason_subject: String.t(),
          record: any(),
          uri: String.t()
        }
end
