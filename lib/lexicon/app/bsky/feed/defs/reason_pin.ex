defmodule Lexicon.App.Bsky.Feed.Defs.ReasonPin do
  @moduledoc """
  Indicates a post appears because it was pinned by its author.

  Part of app.bsky.feed.defs lexicon.
  """

  defstruct []

  @type t :: %__MODULE__{}

  @doc """
  Creates a new reason pin.

  Since this object has no properties, it returns a plain struct.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Validates a reason pin structure.

  For this type, any map is considered valid since it contains no properties.
  """
  def validate(data) when is_map(data) do
    {:ok, %__MODULE__{}}
  end
end
