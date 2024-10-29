# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Label.Defs.SelfLabels do
  @moduledoc """
  Generated schema for selfLabels

  **Description**: Metadata tags on an atproto record, published by the author within the record.
  """

  @enforce_keys [:values]
  defstruct values: nil

  @type t :: %__MODULE__{
          values: list(ProtoRune.Com.Atproto.Label.Defs.SelfLabel.t())
        }
end
