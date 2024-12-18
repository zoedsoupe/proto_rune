# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Repo.ApplyWrites do
  @moduledoc """
  Generated procedure module for main

  **Description**: Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.
  """

  @type output :: %{
          commit: ProtoRune.Com.Atproto.Repo.Defs.CommitMeta.t(),
          results:
            list(
              ProtoRune.Com.Atproto.Repo.ApplyWrites.CreateResult.t()
              | ProtoRune.Com.Atproto.Repo.ApplyWrites.UpdateResult.t()
              | ProtoRune.Com.Atproto.Repo.ApplyWrites.DeleteResult.t()
            )
        }
  @type input :: %{
          repo: String.t(),
          swap_commit: String.t(),
          validate: boolean(),
          writes:
            list(
              ProtoRune.Com.Atproto.Repo.ApplyWrites.Create.t()
              | ProtoRune.Com.Atproto.Repo.ApplyWrites.Update.t()
              | ProtoRune.Com.Atproto.Repo.ApplyWrites.Delete.t()
            )
        }
  @type error :: ProtoRune.Com.Atproto.Repo.ApplyWrites.MainErrorInvalidSwap.t()
end
