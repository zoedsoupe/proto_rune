# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Repo.CreateRecord do
  @moduledoc """
  Generated procedure module for main

  **Description**: Create a single new repository record. Requires auth, implemented by PDS.
  """

  @type output :: %{
          cid: String.t(),
          commit: ProtoRune.Com.Atproto.Repo.Defs.CommitMeta.t(),
          uri: String.t(),
          validation_status: :valid | :unknown
        }
  @type input :: %{
          collection: String.t(),
          record: any(),
          repo: String.t(),
          rkey: String.t(),
          swap_commit: String.t(),
          validate: boolean()
        }
  @type error :: ProtoRune.Com.Atproto.Repo.CreateRecord.MainErrorInvalidSwap.t()
end
