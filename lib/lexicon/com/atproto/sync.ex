defmodule Lexicon.Com.Atproto.Sync do
  @moduledoc """
  Definitions for sync-related data structures.

  NSID: com.atproto.sync
  """

  # Host status values
  @host_status_active "active"
  @host_status_idle "idle"
  @host_status_offline "offline"
  @host_status_throttled "throttled"
  @host_status_banned "banned"

  # Export host status constants
  def host_status_active, do: @host_status_active
  def host_status_idle, do: @host_status_idle
  def host_status_offline, do: @host_status_offline
  def host_status_throttled, do: @host_status_throttled
  def host_status_banned, do: @host_status_banned

  @doc """
  Checks if a host status is valid.
  """
  def valid_host_status?(val) do
    val in [
      @host_status_active,
      @host_status_idle,
      @host_status_offline,
      @host_status_throttled,
      @host_status_banned
    ]
  end
end
