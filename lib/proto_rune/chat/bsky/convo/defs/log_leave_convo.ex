# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Chat.Bsky.Convo.Defs.LogLeaveConvo do
  @moduledoc """
  Generated schema for logLeaveConvo

  **Description**: No description provided.
  """

  @enforce_keys [:rev, :convo_id]
  defstruct convo_id: nil, rev: nil

  @type t :: %__MODULE__{
          convo_id: String.t(),
          rev: String.t()
        }
end
