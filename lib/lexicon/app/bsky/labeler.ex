defmodule Lexicon.App.Bsky.Labeler do
  @moduledoc """
  Definitions for labeler-related data structures.

  NSID: app.bsky.labeler
  """

  alias Lexicon.App.Bsky.Labeler.LabelerPolicies
  alias Lexicon.App.Bsky.Labeler.LabelerView
  alias Lexicon.App.Bsky.Labeler.LabelerViewDetailed
  alias Lexicon.App.Bsky.Labeler.LabelerViewerState

  @doc """
  Validates a labeler view structure.
  """
  def validate_labeler_view(data) when is_map(data) do
    LabelerView.validate(data)
  end

  @doc """
  Validates a detailed labeler view structure.
  """
  def validate_labeler_view_detailed(data) when is_map(data) do
    LabelerViewDetailed.validate(data)
  end

  @doc """
  Validates a labeler viewer state structure.
  """
  def validate_labeler_viewer_state(data) when is_map(data) do
    LabelerViewerState.validate(data)
  end

  @doc """
  Validates a labeler policies structure.
  """
  def validate_labeler_policies(data) when is_map(data) do
    LabelerPolicies.validate(data)
  end
end
