# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Graph.Defs.ListViewerState do
  @moduledoc """
  Generated schema for listViewerState

  **Description**: No description provided.
  """

  defstruct blocked: nil, muted: nil

  @type t :: %__MODULE__{
          blocked: String.t(),
          muted: boolean()
        }
end
