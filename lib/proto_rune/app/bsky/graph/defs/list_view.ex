# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Graph.Defs.ListView do
  @moduledoc """
  Generated schema for listView

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :creator, :name, :purpose, :indexed_at]
  defstruct avatar: nil,
            cid: nil,
            creator: nil,
            description: nil,
            description_facets: nil,
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
          creator: ProtoRune.App.Bsky.Actor.Defs.ProfileView.t(),
          description: String.t(),
          description_facets: list(ProtoRune.App.Bsky.Richtext.Facet.t()),
          indexed_at: String.t(),
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          list_item_count: integer(),
          name: String.t(),
          purpose: ProtoRune.App.Bsky.Graph.Defs.ListPurpose.t(),
          uri: String.t(),
          viewer: ProtoRune.App.Bsky.Graph.Defs.ListViewerState.t()
        }
end