# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Sync.SubscribeRepos.Tombstone do
  @moduledoc """
  Generated schema for tombstone

  **Description**: DEPRECATED -- Use #account event instead
  """

  @enforce_keys [:seq, :did, :time]
  defstruct did: nil, seq: nil, time: nil

  @type t :: %__MODULE__{
          did: String.t(),
          seq: integer(),
          time: String.t()
        }
end
