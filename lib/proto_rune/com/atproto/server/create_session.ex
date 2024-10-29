# This module was generated by Mix.Tasks.GenSchemas
defmodule ProtoRune.Com.Atproto.Server.CreateSession do
  @moduledoc """
  Generated procedure module for main

  **Description**: Create an authentication session.
  """

  @type output :: %{
          access_jwt: String.t(),
          active: boolean(),
          did: String.t(),
          did_doc: any(),
          email: String.t(),
          email_auth_factor: boolean(),
          email_confirmed: boolean(),
          handle: String.t(),
          refresh_jwt: String.t(),
          status: :takendown | :suspended | :deactivated
        }
  @type input :: %{auth_factor_token: String.t(), identifier: String.t(), password: String.t()}
  @type error ::
          ProtoRune.Com.Atproto.Server.CreateSession.MainErrorAccountTakedown.t()
          | ProtoRune.Com.Atproto.Server.CreateSession.MainErrorAuthFactorTokenRequired.t()
end
