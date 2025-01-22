# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.AccountEvent do
  @moduledoc """
  **accountEvent** (object/record)

  Logs account status related events on a repo subject. Normally captured by automod from the firehose and emitted to ozone for historical tracking.
  """

  @enforce_keys [:timestamp, :active]
  defstruct active: nil, comment: nil, status: nil, timestamp: nil

  @type t :: %__MODULE__{
          active: boolean(),
          comment: String.t(),
          status: :unknown | :deactivated | :deleted | :takendown | :suspended | :tombstoned,
          timestamp: String.t()
        }
end
