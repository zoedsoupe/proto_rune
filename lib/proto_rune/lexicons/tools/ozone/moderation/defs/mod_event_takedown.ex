# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.ModEventTakedown do
  @moduledoc """
  **modEventTakedown** (object/record)

  Take down a subject permanently or temporarily
  """

  defstruct acknowledgeAccountSubjects: nil, comment: nil, durationInHours: nil, policies: nil

  @type t :: %__MODULE__{
          acknowledgeAccountSubjects: boolean(),
          comment: String.t(),
          durationInHours: integer(),
          policies: list(String.t())
        }
end
