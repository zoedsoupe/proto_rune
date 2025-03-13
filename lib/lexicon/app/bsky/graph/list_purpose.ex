defmodule Lexicon.App.Bsky.Graph.ListPurpose do
  @moduledoc """
  Defines the purpose of a list in the AT Protocol.

  NSID: app.bsky.graph.defs#listPurpose
  """

  @typedoc """
  List purpose in the AT Protocol:
  - `:modlist` - A list of actors to apply an aggregate moderation action (mute/block) on.
  - `:curatelist` - A list of actors used for curation purposes such as list feeds or interaction gating.
  - `:referencelist` - A list of actors used only for reference purposes such as within a starter pack.
  """
  @type t :: :modlist | :curatelist | :referencelist

  @valid_purposes [:modlist, :curatelist, :referencelist]

  @doc """
  Returns a list of valid list purposes.
  """
  def valid_purposes, do: @valid_purposes

  @doc """
  Validates if a purpose is valid.
  """
  def valid?(purpose) when purpose in @valid_purposes, do: true
  def valid?(_), do: false

  @doc """
  Converts a string purpose to an atom.
  """
  def from_string("app.bsky.graph.defs#modlist"), do: {:ok, :modlist}
  def from_string("app.bsky.graph.defs#curatelist"), do: {:ok, :curatelist}
  def from_string("app.bsky.graph.defs#referencelist"), do: {:ok, :referencelist}
  def from_string(_), do: :error

  @doc """
  Converts a string purpose to an atom, raising an error if invalid.
  """
  def from_string!(purpose) do
    case from_string(purpose) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "Invalid list purpose: #{inspect(purpose)}"
    end
  end

  @doc """
  Converts an atom purpose to a string.
  """
  def to_string(:modlist), do: "app.bsky.graph.defs#modlist"
  def to_string(:curatelist), do: "app.bsky.graph.defs#curatelist"
  def to_string(:referencelist), do: "app.bsky.graph.defs#referencelist"

  def to_string(value) do
    raise ArgumentError, "Invalid list purpose: #{inspect(value)}"
  end
end
