# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Server.UpdateEmail do
  @moduledoc """
  Generated procedure module for main

  **Description**: Update an account's email.
  """

  @type input :: %{email: String.t(), email_auth_factor: boolean(), token: String.t()}
  @type error ::
          ProtoRune.Com.Atproto.Server.UpdateEmail.MainErrorExpiredToken.t()
          | ProtoRune.Com.Atproto.Server.UpdateEmail.MainErrorInvalidToken.t()
          | ProtoRune.Com.Atproto.Server.UpdateEmail.MainErrorTokenRequired.t()
end