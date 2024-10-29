# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Feed.Threadgate.ListRule do
  @moduledoc """
  Generated schema for listRule

  **Description**: Allow replies from actors on a list.
  """

  @enforce_keys [:list]
  defstruct list: nil

  @type t :: %__MODULE__{
          list: String.t()
        }
end