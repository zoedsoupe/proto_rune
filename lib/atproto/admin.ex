defmodule Atproto.Admin do
  @moduledoc false

  import XRPC.DSL

  @doc """
  Delete a user account as an administrator.

  https://docs.bsky.app/docs/api/com-atproto-admin-delete-account
  """
  defprocedure "com.atproto.admin.deleteAccount", authenticated: true do
    param :did, {:required, :string}
  end

  @doc """
  Disable an account from receiving new invite codes, but does not invalidate existing codes.

  https://docs.bsky.app/docs/api/com-atproto-admin-disable-account-invites
  """
  defprocedure "com.atproto.admin.disableAccountInvites", authenticated: true do
    param :account, {:required, :string}
    param :note, :string
  end

  @doc """
  Disable some set of codes and/or all codes associated with a set of users.

  https://docs.bsky.app/docs/api/com-atproto-admin-disable-invite-codes
  """
  defprocedure "com.atproto.admin.disableInviteCodes", authenticated: true do
    param :codes, {:required, {:list, :string}}
    param :accounts, {:required, {:list, :string}}
  end

  @doc """
  Re-enable an account's ability to receive invite codes.

  https://docs.bsky.app/docs/api/com-atproto-admin-enable-account-invites
  """
  defprocedure "com.atproto.admin.enableAccountInvites", authenticated: true do
    param :did, {:required, :string}
    param :note, :string
  end

  @doc """
  Get details about an account.

  https://docs.bsky.app/docs/api/com-atproto-admin-get-account-info
  """
  defquery "com.atproto.admin.getAccountInfo", authenticated: true do
    param :did, {:required, :string}
  end

  @doc """
  Get details about some accounts.

  https://docs.bsky.app/docs/api/com-atproto-admin-get-account-infos
  """
  defquery "com.atproto.admin.getAccountInfos", authenticated: true do
    param :dids, {:required, {:list, :string}}
  end

  @doc """
  Get an admin view of invite codes.

  https://docs.bsky.app/docs/api/com-atproto-admin-get-invite-codes
  """
  defquery "com.atproto.admin.getInviteCodes", authenticated: true

  defquery "com.atproto.admin.getInviteCodes", authenticated: true do
    param :sort, {:enum, [:recent, :usage]}
    param :limit, :integer
    param :cursor, :string
  end

  @doc """
  Get the service-specific admin status of a subject (account, record, or blob).

  https://docs.bsky.app/docs/api/com-atproto-admin-get-subject-status
  """
  defquery "com.atproto.admin.getSubjectStatus", authenticated: true

  defquery "com.atproto.admin.getSubjectStatus", authenticated: true do
    param :did, :string
    param :uri, :string
    param :blob, :string
  end

  @doc """
  Get list of accounts that matches your search query.

  https://docs.bsky.app/docs/api/com-atproto-admin-search-accounts
  """
  defquery "com.atproto.admin.searchAccounts", for: :todo

  defquery "com.atproto.admin.searchAccounts", for: :todo do
    param :email, :string
    param :uri, :string
    param :blob, :string
  end

  @doc """
  Send email to a user's account email address.

  https://docs.bsky.app/docs/api/com-atproto-admin-send-email
  """
  defprocedure "com.atproto.admin.sendEmail", authenticated: true do
    param :content, {:required, :string}
    param :sender_did, {:required, :string}
    param :recipient_did, {:required, :string}
    param :comment, :string
    param :subject, :string
  end

  @doc """
  Administrative action to update an account's email.

  https://docs.bsky.app/docs/api/com-atproto-admin-update-account-email
  """
  defprocedure "com.atproto.admin.updateAccountEmail", authenticated: true do
    param :account, {:required, :string}
    param :email, {:required, :string}
  end

  @doc """
  Administrative action to update an account's handle.

  https://docs.bsky.app/docs/api/com-atproto-admin-update-account-handle
  """
  defprocedure "com.atproto.admin.updateAccountHandle", authenticated: true do
    param :did, {:required, :string}
    param :handle, {:required, :string}
  end

  @doc """
  Administrative action to update an account's password.

  https://docs.bsky.app/docs/api/com-atproto-admin-update-account-password
  """
  defprocedure "com.atproto.admin.updateAccountPassword", authenticated: true do
    param :did, {:required, :string}
    param :password, {:required, :string}
  end

  @subject {:oneof,
            [
              %{did: {:required, :string}},
              %{uri: {:required, :string}, cid: {:required, :string}},
              %{uri: {:required, :string}, cid: {:required, :string}, record_uri: :string}
            ]}

  @doc """
    
  """
  defprocedure "com.atproto.admin.updateSubjectStatus", authenticated: true do
    param :subject, {:required, @subject}
    param :takedown, %{applied: {:required, :boolean}, ref: :string}
    param :deactivated, %{applied: {:required, :boolean}, ref: :string}
  end
end
