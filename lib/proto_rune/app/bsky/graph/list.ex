# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Graph.List do
  @moduledoc """
  Generated schema for main

  **Description**: No description provided.
  """

  @enforce_keys [:name, :purpose, :created_at]
  defstruct avatar: nil,
            created_at: nil,
            description: nil,
            description_facets: nil,
            labels: nil,
            name: nil,
            purpose: nil

  @type t :: %__MODULE__{
          avatar: binary(),
          created_at: String.t(),
          description: String.t(),
          description_facets: list(ProtoRune.App.Bsky.Richtext.Facet.t()),
          labels: ProtoRune.Com.Atproto.Label.Defs.SelfLabels.t(),
          name: String.t(),
          purpose: ProtoRune.App.Bsky.Graph.Defs.ListPurpose.t()
        }
end
