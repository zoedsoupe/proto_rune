defmodule Atproto.Server do
  @moduledoc false

  import XRPC.DSL

  @doc """
  Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.

  https://docs.bsky.app/docs/api/com-atproto-server-activate-account
  """
  defprocedure "com.atproto.server.activateAccount", authenticated: true

  @doc """
  Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.

  https://docs.bsky.app/docs/api/com-atproto-server-check-account-status
  """
  defquery "com.atproto.server.checkAccountStatus", authenticated: true

  @doc """
  Confirm an email using a token from com.atproto.server.requestEmailConfirmation.

  https://docs.bsky.app/docs/api/com-atproto-server-confirm-email
  """
  defprocedure "com.atproto.server.confirmEmail", authenticated: true do
    param :email, {:required, :string}
    param :token, {:required, :string}
  end

  @doc """
  Create an account. Implemented by PDS.

  https://docs.bsky.app/docs/api/com-atproto-server-create-account
  """
  defprocedure "com.atproto.server.createAccount", authenticated: true do
    param :handle, {:required, :string}
    param :email, :string
    param :did, :string
    param :invite_code, :string
    param :verification_code, :string
    param :verification_phone, :string
    param :password, :string
    param :recovery_key, :string
    param :plc_op, :string
  end

  @doc """
  Create an App Password.

  https://docs.bsky.app/docs/api/com-atproto-server-create-app-password
  """
  defprocedure "com.atproto.server.createAppPassword", authenticated: true do
    param :name, {:required, :string}
    param :privileged, :boolean
  end

  @doc """
  Create an invite code.

  https://docs.bsky.app/docs/api/com-atproto-server-create-invite-code
  """
  defprocedure "com.atproto.server.createInviteCode", authenticated: true do
    param :use_count, {:required, :integer}
    param :for_account, :string
  end

  @doc """
  Create invite codes.

  https://docs.bsky.app/docs/api/com-atproto-server-create-invite-codes
  """
  defprocedure "com.atproto.server.createInviteCodes", authenticated: true do
    param :code_count, {:required, :integer}
    param :use_count, {:required, :integer}
    param :for_accounts, {:list, :string}
  end

  @doc """
  Create an authentication session.

  https://docs.bsky.app/docs/api/com-atproto-server-create-session
  """
  defprocedure "com.atproto.server.createSession", for: :todo do
    param :identifier, {:required, :string}
    param :password, {:required, :string}
    param :auth_factor_code, :string
  end

  @doc """
  Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.

  https://docs.bsky.app/docs/api/com-atproto-server-deactivate-account
  """
  defprocedure "com.atproto.server.deactivateAccount", authenticated: true do
    param :delete_after, {:required, :datetime}
  end

  @doc """
  Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.

  https://docs.bsky.app/docs/api/com-atproto-server-delete-account
  """
  defprocedure "com.atproto.server.deleteAccount", authenticated: true do
    param :did, {:required, :string}
    param :password, {:required, :string}
    param :token, {:required, :string}
  end

  @doc """
  Delete the current session. Requires auth.

  https://docs.bsky.app/docs/api/com-atproto-server-delete-session
  """
  defprocedure "com.atproto.server.deleteSession", authenticated: true

  @doc """
  Describes the server's account creation requirements and capabilities. Implemented by PDS.

  https://docs.bsky.app/docs/api/com-atproto-server-describe-server
  """
  defquery "com.atproto.server.describeServer", for: :todo

  @doc """
  Get all invite codes for the current account. Requires auth.
  """
  defquery "com.atproto.server.getAccountInviteCodes", authenticated: true do
    param :include_used, :boolean
    param :create_available, :boolean
  end

  @doc """
  Get a signed token on behalf of the requesting DID for the requested service.

  https://docs.bsky.app/docs/api/com-atproto-server-get-service-auth
  """
  defquery "com.atproto.server.getServiceAuth", for: :todo do
    param :aud, {:required, :string}
    param :exp, :integer
    param :lxm, :string
  end

  @doc """
  Get information about the current auth session. Requires auth.

  https://docs.bsky.app/docs/api/com-atproto-server-get-session
  """
  defquery "com.atproto.server.getSession", authenticated: true

  @doc """
  List all App Passwords

  https://docs.bsky.app/docs/api/com-atproto-server-list-app-passwords
  """
  defquery "com.atproto.server.listAppPasswords", authenticated: true

  @doc """
  Refresh an authentication session. Requires auth using the 'refresh_jwt' (not the 'access_jwt').

  https://docs.bsky.app/docs/api/com-atproto-server-refresh-session
  """
  defprocedure "com.atproto.server.refreshSession", refresh: true

  @doc """
  Initiate a user account deletion via email.

  https://docs.bsky.app/docs/api/com-atproto-server-request-account-delete
  """
  defprocedure "com.atproto.server.requestAccountDelete", authenticated: true

  @doc """
  Request an email with a code to confirm ownership of email.

  https://docs.bsky.app/docs/api/com-atproto-server-request-email-confirmation
  """
  defprocedure "com.atproto.server.requestEmailConfirmation", authenticated: true

  @doc """
  Request a token in order to update email.

  https://docs.bsky.app/docs/api/com-atproto-server-request-email-update
  """
  defprocedure "com.atproto.server.requestEmailUpdate", authenticated: true

  @doc """
  Initiate a user account password reset via email.

  https://docs.bsky.app/docs/api/com-atproto-server-request-password-reset
  """
  defprocedure "com.atproto.server.requestPasswordReset", for: :todo do
    param :email, {:required, :string}
  end

  @doc """
  Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.

  https://docs.bsky.app/docs/api/com-atproto-server-reserve-signing-key
  """
  defprocedure "com.atproto.server.reserveSigningKey", for: :todo do
    param :did, {:required, :string}
  end

  @doc """
  Reset a user account password using a token.

  https://docs.bsky.app/docs/api/com-atproto-server-reset-password
  """
  defprocedure "com.atproto.server.resetPassword", for: :todo do
    param :token, {:required, :string}
    param :password, {:required, :string}
  end

  @doc """
  Revoke an App Password by name.

  https://docs.bsky.app/docs/api/com-atproto-server-revoke-app-password
  """
  defprocedure "com.atproto.server.revokeAppPassword", authenticated: true do
    param :name, {:required, :string}
  end

  @doc """
  Update an account's email.

  https://docs.bsky.app/docs/api/com-atproto-server-update-email
  """
  defprocedure "com.atproto.server.updateEmail", for: :todo do
    param :email, {:required, :string}
    param :email_auth_factor, :string
    param :token, :string
  end
end
