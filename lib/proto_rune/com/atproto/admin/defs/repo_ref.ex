# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Admin.Defs.RepoRef do
  @moduledoc """
  Generated schema for repoRef

  **Description**: No description provided.
  """

  @enforce_keys [:did]
  defstruct did: nil

  @type t :: %__MODULE__{
          did: String.t()
        }
end
