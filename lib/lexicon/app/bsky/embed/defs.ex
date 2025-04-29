defmodule Lexicon.App.Bsky.Embed.Defs do
  @moduledoc """
  Definitions for embed-related data structures.

  NSID: app.bsky.embed.defs
  """

  alias Lexicon.App.Bsky.Embed.Defs.AspectRatio

  @doc """
  Validates an aspect ratio structure.
  """
  def validate_aspect_ratio(data) when is_map(data) do
    AspectRatio.validate(data)
  end
end
