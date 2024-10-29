# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Unspecced.SearchPostsSkeleton do
  @moduledoc """
  Generated schema for main

  **Description**: No description provided.
  """

  @type t :: %{
          author: String.t(),
          cursor: String.t(),
          domain: String.t(),
          lang: String.t(),
          limit: integer(),
          mentions: String.t(),
          q: String.t(),
          since: String.t(),
          sort: :top | :latest,
          tag: list(String.t()),
          until: String.t(),
          url: String.t(),
          viewer: String.t()
        }
end
