# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Sync.SubscribeRepos.Info do
  @moduledoc """
  Generated schema for info

  **Description**: No description provided.
  """

  @enforce_keys [:name]
  defstruct message: nil, name: nil

  @type t :: %__MODULE__{
          message: String.t(),
          name: :OutdatedCursor
        }
end
