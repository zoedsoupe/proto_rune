# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Repo.ListMissingBlobs.RecordBlob do
  @moduledoc """
  Generated schema for recordBlob

  **Description**: No description provided.
  """

  @enforce_keys [:cid, :record_uri]
  defstruct cid: nil, record_uri: nil

  @type t :: %__MODULE__{
          cid: String.t(),
          record_uri: String.t()
        }
end
