# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Label.SubscribeLabels.Labels do
  @moduledoc """
  Generated schema for labels

  **Description**: No description provided.
  """

  @enforce_keys [:seq, :labels]
  defstruct labels: nil, seq: nil

  @type t :: %__MODULE__{
          labels: list(ProtoRune.Com.Atproto.Label.Defs.Label.t()),
          seq: integer()
        }
end
