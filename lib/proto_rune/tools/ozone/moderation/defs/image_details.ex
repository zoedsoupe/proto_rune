# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Tools.Ozone.Moderation.Defs.ImageDetails do
  @moduledoc """
  Generated schema for imageDetails

  **Description**: No description provided.
  """

  @enforce_keys [:width, :height]
  defstruct height: nil, width: nil

  @type t :: %__MODULE__{
          height: integer(),
          width: integer()
        }
end