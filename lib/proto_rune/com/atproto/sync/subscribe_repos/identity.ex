# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Sync.SubscribeRepos.Identity do
  @moduledoc """
  Generated schema for identity

  **Description**: Represents a change to an account's identity. Could be an updated handle, signing key, or pds hosting endpoint. Serves as a prod to all downstream services to refresh their identity cache.
  """

  @enforce_keys [:seq, :did, :time]
  defstruct did: nil, handle: nil, seq: nil, time: nil

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          seq: integer(),
          time: String.t()
        }
end