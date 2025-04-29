defmodule Lexicon.App.Bsky.Embed do
  @moduledoc """
  Definitions for embed-related data structures.

  NSID: app.bsky.embed
  """

  alias Lexicon.App.Bsky.Embed.AspectRatio

  @doc """
  Validates an aspect ratio structure.
  """
  def validate_aspect_ratio(data) when is_map(data) do
    AspectRatio.validate(data)
  end
end
