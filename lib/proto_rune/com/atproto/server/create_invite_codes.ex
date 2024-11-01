# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Server.CreateInviteCodes do
  @moduledoc """
  Generated procedure module for main

  **Description**: Create invite codes.
  """

  @type output :: %{codes: list(ProtoRune.Com.Atproto.Server.CreateInviteCodes.AccountCodes.t())}
  @type input :: %{code_count: integer(), for_accounts: list(String.t()), use_count: integer()}
end
