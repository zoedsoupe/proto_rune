# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Actor.Defs.ViewerState do
  @moduledoc """
  Generated schema for viewerState

  **Description**: Metadata about the requesting account's relationship with the subject account. Only has meaningful content for authed requests.
  """

  defstruct blocked_by: nil,
            blocking: nil,
            blocking_by_list: nil,
            followed_by: nil,
            following: nil,
            known_followers: nil,
            muted: nil,
            muted_by_list: nil

  @type t :: %__MODULE__{
          blocked_by: boolean(),
          blocking: String.t(),
          blocking_by_list: ProtoRune.App.Bsky.Graph.Defs.ListViewBasic.t(),
          followed_by: String.t(),
          following: String.t(),
          known_followers: ProtoRune.App.Bsky.Actor.Defs.KnownFollowers.t(),
          muted: boolean(),
          muted_by_list: ProtoRune.App.Bsky.Graph.Defs.ListViewBasic.t()
        }
end
