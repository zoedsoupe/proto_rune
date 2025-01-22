# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.AccountStats do
  @moduledoc """
  **accountStats** (object/record)

  Statistics about a particular account subject
  """

  defstruct appealCount: nil,
            escalateCount: nil,
            reportCount: nil,
            suspendCount: nil,
            takedownCount: nil

  @type t :: %__MODULE__{
          appealCount: integer(),
          escalateCount: integer(),
          reportCount: integer(),
          suspendCount: integer(),
          takedownCount: integer()
        }
end
