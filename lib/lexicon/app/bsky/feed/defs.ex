defmodule Lexicon.App.Bsky.Feed.Defs do
  @moduledoc """
  Definitions for feed-related data structures.

  NSID: app.bsky.feed.defs
  """

  # Token definitions as module attributes
  @content_mode_unspecified "app.bsky.feed.defs#contentModeUnspecified"
  @content_mode_video "app.bsky.feed.defs#contentModeVideo"
  @request_less "app.bsky.feed.defs#requestLess"
  @request_more "app.bsky.feed.defs#requestMore"
  @clickthrough_item "app.bsky.feed.defs#clickthroughItem"
  @clickthrough_author "app.bsky.feed.defs#clickthroughAuthor"
  @clickthrough_reposter "app.bsky.feed.defs#clickthroughReposter"
  @clickthrough_embed "app.bsky.feed.defs#clickthroughEmbed"
  @interaction_seen "app.bsky.feed.defs#interactionSeen"
  @interaction_like "app.bsky.feed.defs#interactionLike"
  @interaction_repost "app.bsky.feed.defs#interactionRepost"
  @interaction_reply "app.bsky.feed.defs#interactionReply"
  @interaction_quote "app.bsky.feed.defs#interactionQuote"
  @interaction_share "app.bsky.feed.defs#interactionShare"

  # Export token constants as functions
  def content_mode_unspecified, do: @content_mode_unspecified
  def content_mode_video, do: @content_mode_video
  def request_less, do: @request_less
  def request_more, do: @request_more
  def clickthrough_item, do: @clickthrough_item
  def clickthrough_author, do: @clickthrough_author
  def clickthrough_reposter, do: @clickthrough_reposter
  def clickthrough_embed, do: @clickthrough_embed
  def interaction_seen, do: @interaction_seen
  def interaction_like, do: @interaction_like
  def interaction_repost, do: @interaction_repost
  def interaction_reply, do: @interaction_reply
  def interaction_quote, do: @interaction_quote
  def interaction_share, do: @interaction_share

  @doc """
  Checks if a content mode value is valid.
  """
  def valid_content_mode?(mode) do
    mode in [@content_mode_unspecified, @content_mode_video]
  end

  @doc """
  Checks if an interaction event value is valid.
  """
  def valid_interaction_event?(event) do
    event in [
      @request_less,
      @request_more,
      @clickthrough_item,
      @clickthrough_author,
      @clickthrough_reposter,
      @clickthrough_embed,
      @interaction_seen,
      @interaction_like,
      @interaction_repost,
      @interaction_reply,
      @interaction_quote,
      @interaction_share
    ]
  end
end
