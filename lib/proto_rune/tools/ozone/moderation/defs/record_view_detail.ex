# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.RecordViewDetail do
  @moduledoc """
  Generated schema for recordViewDetail

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :value, :blobs, :indexed_at, :moderation, :repo]
  defstruct blobs: nil,
            cid: nil,
            indexed_at: nil,
            labels: nil,
            moderation: nil,
            repo: nil,
            uri: nil,
            value: nil

  @type t :: %__MODULE__{
          blobs: list(ProtoRune.Tools.Ozone.Moderation.Defs.BlobView.t()),
          cid: String.t(),
          indexed_at: String.t(),
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          moderation: ProtoRune.Tools.Ozone.Moderation.Defs.ModerationDetail.t(),
          repo: ProtoRune.Tools.Ozone.Moderation.Defs.RepoView.t(),
          uri: String.t(),
          value: any()
        }
end