# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Repo.ListRecords.Record do
  @moduledoc """
  Generated schema for record

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :value]
  defstruct cid: nil, uri: nil, value: nil

  @type t :: %__MODULE__{
          cid: String.t(),
          uri: String.t(),
          value: any()
        }
end
