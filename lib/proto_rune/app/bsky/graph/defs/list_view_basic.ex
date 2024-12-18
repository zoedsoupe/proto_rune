# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Graph.Defs.ListViewBasic do
  @moduledoc """
  Generated schema for listViewBasic

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :name, :purpose]
  defstruct avatar: nil,
            cid: nil,
            indexed_at: nil,
            labels: nil,
            list_item_count: nil,
            name: nil,
            purpose: nil,
            uri: nil,
            viewer: nil

  @type t :: %__MODULE__{
          avatar: String.t(),
          cid: String.t(),
          indexed_at: String.t(),
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          list_item_count: integer(),
          name: String.t(),
          purpose: ProtoRune.App.Bsky.Graph.Defs.ListPurpose.t(),
          uri: String.t(),
          viewer: ProtoRune.App.Bsky.Graph.Defs.ListViewerState.t()
        }
end
