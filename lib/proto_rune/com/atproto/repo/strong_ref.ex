# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Repo.StrongRef do
  @moduledoc """
  Generated schema for main

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid]
  defstruct cid: nil, uri: nil

  @type t :: %__MODULE__{
          cid: String.t(),
          uri: String.t()
        }
end
