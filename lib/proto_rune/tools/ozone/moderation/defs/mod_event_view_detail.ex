# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.ModEventViewDetail do
  @moduledoc """
  Generated schema for modEventViewDetail

  **Description**: No description provided.
  """

  @enforce_keys [:id, :event, :subject, :subject_blobs, :created_by, :created_at]
  defstruct created_at: nil,
            created_by: nil,
            event: nil,
            id: nil,
            subject: nil,
            subject_blobs: nil

  @type t :: %__MODULE__{
          created_at: String.t(),
          created_by: String.t(),
          event:
            ProtoRune.Tools.Ozone.Moderation.Defs.ModEventTakedown.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventReverseTakedown.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventComment.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventReport.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventLabel.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventAcknowledge.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventEscalate.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventMute.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventUnmute.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventMuteReporter.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventUnmuteReporter.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventEmail.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventResolveAppeal.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventDivert.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.ModEventTag.t(),
          id: integer(),
          subject:
            ProtoRune.Tools.Ozone.Moderation.Defs.RepoView.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.RepoViewNotFound.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.RecordView.t()
            | ProtoRune.Tools.Ozone.Moderation.Defs.RecordViewNotFound.t(),
          subject_blobs: list(ProtoRune.Tools.Ozone.Moderation.Defs.BlobView.t())
        }
end
