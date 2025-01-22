# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Richtext.Facet.Mention do
  @moduledoc """
  **mention** (object/record)

  Facet feature for mention of another account. The text is usually a handle, including a '@' prefix, but the facet reference is a DID.
  """

  @enforce_keys [:did]
  defstruct did: nil

  @type t :: %__MODULE__{
          did: String.t()
        }
end
