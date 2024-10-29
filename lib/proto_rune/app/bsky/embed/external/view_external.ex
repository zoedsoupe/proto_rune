# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Embed.External.ViewExternal do
  @moduledoc """
  Generated schema for viewExternal

  **Description**: No description provided.
  """

  @enforce_keys [:uri, :title, :description]
  defstruct description: nil, thumb: nil, title: nil, uri: nil

  @type t :: %__MODULE__{
          description: String.t(),
          thumb: String.t(),
          title: String.t(),
          uri: String.t()
        }
end