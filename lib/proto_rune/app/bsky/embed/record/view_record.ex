# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Embed.Record.ViewRecord do
  @moduledoc """
  Generated schema for viewRecord

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :cid, :author, :value, :indexed_at]
  defstruct author: nil,
            cid: nil,
            embeds: nil,
            indexed_at: nil,
            labels: nil,
            like_count: nil,
            quote_count: nil,
            reply_count: nil,
            repost_count: nil,
            uri: nil,
            value: nil

  @type t :: %__MODULE__{
          author: ProtoRune.App.Bsky.Actor.Defs.ProfileViewBasic.t(),
          cid: String.t(),
          embeds:
            list(
              ProtoRune.App.Bsky.Embed.Images.View.t()
              | ProtoRune.App.Bsky.Embed.Video.View.t()
              | ProtoRune.App.Bsky.Embed.External.View.t()
              | ProtoRune.App.Bsky.Embed.Record.View.t()
              | ProtoRune.App.Bsky.Embed.RecordWithMedia.View.t()
            ),
          indexed_at: String.t(),
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          like_count: integer(),
          quote_count: integer(),
          reply_count: integer(),
          repost_count: integer(),
          uri: String.t(),
          value: any()
        }
end
