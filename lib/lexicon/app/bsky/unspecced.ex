defmodule Lexicon.App.Bsky.Unspecced do
  @moduledoc """
  Definitions for unspecified data structures.

  NSID: app.bsky.unspecced
  """

  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchActor
  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchPost
  alias Lexicon.App.Bsky.Unspecced.SkeletonSearchStarterPack
  alias Lexicon.App.Bsky.Unspecced.SkeletonTrend
  alias Lexicon.App.Bsky.Unspecced.TrendingTopic
  alias Lexicon.App.Bsky.Unspecced.TrendView

  # Known values for trend status
  @trend_status_hot "hot"

  # Export trend status constants
  def trend_status_hot, do: @trend_status_hot

  @doc """
  Checks if a trend status value is valid.
  """
  def valid_trend_status?(status) do
    status in [@trend_status_hot]
  end

  @doc """
  Validates a skeleton search post structure.
  """
  def validate_skeleton_search_post(data) when is_map(data) do
    SkeletonSearchPost.validate(data)
  end

  @doc """
  Validates a skeleton search actor structure.
  """
  def validate_skeleton_search_actor(data) when is_map(data) do
    SkeletonSearchActor.validate(data)
  end

  @doc """
  Validates a skeleton search starter pack structure.
  """
  def validate_skeleton_search_starter_pack(data) when is_map(data) do
    SkeletonSearchStarterPack.validate(data)
  end

  @doc """
  Validates a trending topic structure.
  """
  def validate_trending_topic(data) when is_map(data) do
    TrendingTopic.validate(data)
  end

  @doc """
  Validates a skeleton trend structure.
  """
  def validate_skeleton_trend(data) when is_map(data) do
    SkeletonTrend.validate(data)
  end

  @doc """
  Validates a trend view structure.
  """
  def validate_trend_view(data) when is_map(data) do
    TrendView.validate(data)
  end
end
