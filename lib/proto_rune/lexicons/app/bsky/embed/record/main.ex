# Generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.App.Bsky.Embed.Record.Main do
  @moduledoc """
  **main** (object/record)

  No description.
  """

  @enforce_keys [:record]
  defstruct record: nil

  @type t :: %__MODULE__{
          record: ProtoRune.Com.Atproto.Repo.StrongRef.Main.t()
        }
end
