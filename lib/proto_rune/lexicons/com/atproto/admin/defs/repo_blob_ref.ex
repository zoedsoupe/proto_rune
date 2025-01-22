# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Admin.Defs.RepoBlobRef do
  @moduledoc """
  **repoBlobRef** (object/record)

  No description.
  """

  @enforce_keys [:did, :cid]
  defstruct cid: nil, did: nil, recordUri: nil

  @type t :: %__MODULE__{
          cid: String.t(),
          did: String.t(),
          recordUri: String.t()
        }
end
