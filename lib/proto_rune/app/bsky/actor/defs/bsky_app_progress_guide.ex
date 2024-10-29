# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Actor.Defs.BskyAppProgressGuide do
  @moduledoc """
  Generated schema for bskyAppProgressGuide

  **Description**: If set, an active progress guide. Once completed, can be set to undefined. Should have unspecced fields tracking progress.
  """

  @enforce_keys [:guide]
  defstruct guide: nil

  @type t :: %__MODULE__{
          guide: String.t()
        }
end
