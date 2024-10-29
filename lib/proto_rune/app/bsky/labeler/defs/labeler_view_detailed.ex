# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Labeler.Defs.LabelerViewDetailed do
  @moduledoc """
  Generated schema for labelerViewDetailed

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :creator, :policies, :indexed_at]
  defstruct cid: nil,
            creator: nil,
            indexed_at: nil,
            labels: nil,
            like_count: nil,
            policies: nil,
            uri: nil,
            viewer: nil

  @type t :: %__MODULE__{
          cid: String.t(),
          creator: ProtoRune.App.Bsky.Actor.Defs.ProfileView.t(),
          indexed_at: String.t(),
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          like_count: integer(),
          policies: ProtoRune.App.Bsky.Labeler.Defs.LabelerPolicies.t(),
          uri: String.t(),
          viewer: ProtoRune.App.Bsky.Labeler.Defs.LabelerViewerState.t()
        }
end
