defmodule ProtoRune.Bsky.Notification do
  @moduledoc false

  import ProtoRune.XRPC.DSL

  @doc """
  Count the number of unread notifications for the requesting account. Requires auth.
  """
  defquery "app.bsky.notification.getUnreadCount", authenticated: true do
    param :priority, :boolean
    param :seen_at, :datetime
  end

  @doc """
  Enumerate notifications for the requesting account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-list-notifications
  """
  defquery "app.bsky.notification.listNotifications", authenticated: true

  defquery "app.bsky.notification.listNotifications", authenticated: true do
    param :limit, :integer
    param :priority, :boolean
    param :cursor, :string
    param :seen_at, :datetime
  end

  @doc """
  Set notification-related preferences for an account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-put-preferences
  """
  defprocedure "app.bsky.notification.putPreferences", authenticated: true do
    param :priority, {:required, :boolean}
  end

  @doc """
  Register to receive push notifications, via a specified service, for the requesting account. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-register-push
  """
  defprocedure "app.bsky.notification.registerPush", authenticated: true do
    param :service_did, {:required, :string}
    param :token, {:required, :string}
    param :platform, {:required, {:enum, [:ios, :android, :web]}}
    param :app_id, {:required, :string}
  end

  @doc """
  Notify server that the requesting account has seen notifications. Requires auth.

  https://docs.bsky.app/docs/api/app-bsky-notification-update-seen
  """
  defprocedure "app.bsky.notification.updateSeen", authenticated: true do
    param :seen_at, {:required, :datetime}
  end
end
