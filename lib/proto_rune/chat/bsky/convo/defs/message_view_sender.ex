# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Chat.Bsky.Convo.Defs.MessageViewSender do
  @moduledoc """
  Generated schema for messageViewSender

  **Description**: No description provided.
  """

  @enforce_keys [:did]
  defstruct did: nil

  @type t :: %__MODULE__{
          did: String.t()
        }
end