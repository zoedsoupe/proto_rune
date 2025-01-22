# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Feed.Defs.FeedViewPost do
  @moduledoc """
  **feedViewPost** (object/record)

  No description.
  """

  @enforce_keys [:post]
  defstruct feedContext: nil, post: nil, reason: nil, reply: nil

  @type t :: %__MODULE__{
          feedContext: String.t(),
          post: ProtoRune.App.Bsky.Feed.Defs.PostView.t(),
          reason:
            ProtoRune.App.Bsky.Feed.Defs.ReasonRepost.t()
            | ProtoRune.App.Bsky.Feed.Defs.ReasonPin.t(),
          reply: ProtoRune.App.Bsky.Feed.Defs.ReplyRef.t()
        }
end
