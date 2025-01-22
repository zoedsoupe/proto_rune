# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Feed.GetLikes.Like do
  @moduledoc """
  **like** (object/record)

  No description.
  """

  @enforce_keys [:indexedAt, :createdAt, :actor]
  defstruct actor: nil, createdAt: nil, indexedAt: nil

  @type t :: %__MODULE__{
          actor: ProtoRune.App.Bsky.Actor.Defs.ProfileView.t(),
          createdAt: String.t(),
          indexedAt: String.t()
        }
end
