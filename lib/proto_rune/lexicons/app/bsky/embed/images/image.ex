# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Embed.Images.Image do
  @moduledoc """
  **image** (object/record)

  No description.
  """

  @enforce_keys [:image, :alt]
  defstruct alt: nil, aspectRatio: nil, image: nil

  @type t :: %__MODULE__{
          alt: String.t(),
          aspectRatio: ProtoRune.App.Bsky.Embed.Defs.AspectRatio.t(),
          image: binary()
        }
end
