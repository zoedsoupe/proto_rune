# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Actor.Defs.ProfileAssociatedChat do
  @moduledoc """
  **profileAssociatedChat** (object/record)

  No description.
  """

  @enforce_keys [:allowIncoming]
  defstruct allowIncoming: nil

  @type t :: %__MODULE__{
          allowIncoming: :all | :none | :following
        }
end
