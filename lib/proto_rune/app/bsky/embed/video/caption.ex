# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Embed.Video.Caption do
  @moduledoc """
  Generated schema for caption

  **Description**: No description provided.
  """

  @enforce_keys [:lang, :file]
  defstruct file: nil, lang: nil

  @type t :: %__MODULE__{
          file: binary(),
          lang: String.t()
        }
end
