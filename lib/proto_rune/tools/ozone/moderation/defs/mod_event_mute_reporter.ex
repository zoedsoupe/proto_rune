# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.ModEventMuteReporter do
  @moduledoc """
  Generated schema for modEventMuteReporter

  **Description**: Mute incoming reports from an account
  """

  @enforce_keys [:duration_in_hours]
  defstruct comment: nil, duration_in_hours: nil

  @type t :: %__MODULE__{
          comment: String.t(),
          duration_in_hours: integer()
        }
end