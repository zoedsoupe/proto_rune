# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Graph.Defs.Relationship do
  @moduledoc """
  **relationship** (object/record)

  lists the bi-directional graph relationships between one actor (not indicated in the object), and the target actors (the DID included in the object)
  """

  @enforce_keys [:did]
  defstruct did: nil, followedBy: nil, following: nil

  @type t :: %__MODULE__{
          did: String.t(),
          followedBy: String.t(),
          following: String.t()
        }
end
