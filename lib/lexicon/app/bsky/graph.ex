defmodule Lexicon.App.Bsky.Graph do
  @moduledoc """
  Definitions for graph-related data structures.

  NSID: app.bsky.graph
  """

  # Token definitions as module attributes
  @list_purpose_modlist "app.bsky.graph.defs#modlist"
  @list_purpose_curatelist "app.bsky.graph.defs#curatelist"
  @list_purpose_referencelist "app.bsky.graph.defs#referencelist"

  # Export token constants as functions
  def list_purpose_modlist, do: @list_purpose_modlist
  def list_purpose_curatelist, do: @list_purpose_curatelist
  def list_purpose_referencelist, do: @list_purpose_referencelist

  @doc """
  Checks if a list purpose value is valid.
  """
  def valid_list_purpose?(purpose) do
    purpose in [@list_purpose_modlist, @list_purpose_curatelist, @list_purpose_referencelist]
  end
end
