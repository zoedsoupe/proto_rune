# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Feed.Defs.ReasonRepost do
  @moduledoc """
  Generated schema for reasonRepost

  **Description**: No description provided.
  """

  @enforce_keys [:by, :indexed_at]
  defstruct by: nil, indexed_at: nil

  @type t :: %__MODULE__{
          by: ProtoRune.App.Bsky.Actor.Defs.ProfileViewBasic.t(),
          indexed_at: String.t()
        }
end