defmodule Lexicon.App.Bsky.Actor.Defs do
  @moduledoc """
  Definitions for actor-related data structures.

  NSID: app.bsky.actor.defs
  """

  # Known values for chat preferences
  @chat_allow_incoming_all "all"
  @chat_allow_incoming_none "none"
  @chat_allow_incoming_following "following"

  # Known values for content label visibility
  @content_visibility_ignore "ignore"
  @content_visibility_show "show"
  @content_visibility_warn "warn"
  @content_visibility_hide "hide"

  # Known values for thread sorting
  @thread_sort_oldest "oldest"
  @thread_sort_newest "newest"
  @thread_sort_most_likes "most-likes"
  @thread_sort_random "random"
  @thread_sort_hotness "hotness"

  # Known values for muted word targets
  @muted_word_target_content "content"
  @muted_word_target_tag "tag"

  # Known values for muted word actor targets
  @muted_word_actor_target_all "all"
  @muted_word_actor_target_exclude_following "exclude-following"

  # Export chat preferences constants
  def chat_allow_incoming_all, do: @chat_allow_incoming_all
  def chat_allow_incoming_none, do: @chat_allow_incoming_none
  def chat_allow_incoming_following, do: @chat_allow_incoming_following

  @doc """
  Checks if a chat allow incoming value is valid.
  """
  def valid_chat_allow_incoming?(val) do
    val in [@chat_allow_incoming_all, @chat_allow_incoming_none, @chat_allow_incoming_following]
  end

  # Export content visibility constants
  def content_visibility_ignore, do: @content_visibility_ignore
  def content_visibility_show, do: @content_visibility_show
  def content_visibility_warn, do: @content_visibility_warn
  def content_visibility_hide, do: @content_visibility_hide

  @doc """
  Checks if a content visibility value is valid.
  """
  def valid_content_visibility?(val) do
    val in [
      @content_visibility_ignore,
      @content_visibility_show,
      @content_visibility_warn,
      @content_visibility_hide
    ]
  end

  # Export thread sort constants
  def thread_sort_oldest, do: @thread_sort_oldest
  def thread_sort_newest, do: @thread_sort_newest
  def thread_sort_most_likes, do: @thread_sort_most_likes
  def thread_sort_random, do: @thread_sort_random
  def thread_sort_hotness, do: @thread_sort_hotness

  @doc """
  Checks if a thread sort value is valid.
  """
  def valid_thread_sort?(val) do
    val in [
      @thread_sort_oldest,
      @thread_sort_newest,
      @thread_sort_most_likes,
      @thread_sort_random,
      @thread_sort_hotness
    ]
  end

  # Export muted word target constants
  def muted_word_target_content, do: @muted_word_target_content
  def muted_word_target_tag, do: @muted_word_target_tag

  @doc """
  Checks if a muted word target value is valid.
  """
  def valid_muted_word_target?(val) do
    val in [@muted_word_target_content, @muted_word_target_tag]
  end

  # Export muted word actor target constants
  def muted_word_actor_target_all, do: @muted_word_actor_target_all
  def muted_word_actor_target_exclude_following, do: @muted_word_actor_target_exclude_following

  @doc """
  Checks if a muted word actor target value is valid.
  """
  def valid_muted_word_actor_target?(val) do
    val in [@muted_word_actor_target_all, @muted_word_actor_target_exclude_following]
  end
end
