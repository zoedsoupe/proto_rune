# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Feed.Generator do
  @moduledoc """
  Generated schema for main

  **Description**: No description provided.
  """

  @enforce_keys [:did, :display_name, :created_at]
  defstruct accepts_interactions: nil,
            avatar: nil,
            created_at: nil,
            description: nil,
            description_facets: nil,
            did: nil,
            display_name: nil,
            labels: nil

  @type t :: %__MODULE__{
          accepts_interactions: boolean(),
          avatar: binary(),
          created_at: String.t(),
          description: String.t(),
          description_facets: list(ProtoRune.App.Bsky.Richtext.Facet.t()),
          did: String.t(),
          display_name: String.t(),
          labels: ProtoRune.Com.Atproto.Label.Defs.SelfLabels.t()
        }
end