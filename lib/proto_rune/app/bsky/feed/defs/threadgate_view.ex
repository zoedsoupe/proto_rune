# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Feed.Defs.ThreadgateView do
  @moduledoc """
  Generated schema for threadgateView

  **Description**: No description provided.
  """

  defstruct cid: nil, lists: nil, record: nil, uri: nil

  @type t :: %__MODULE__{
          cid: String.t(),
          lists: list(ProtoRune.App.Bsky.Graph.Defs.ListViewBasic.t()),
          record: any(),
          uri: String.t()
        }
end