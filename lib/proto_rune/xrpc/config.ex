defmodule ProtoRune.XRPC.Config do
  @moduledoc """
  Provides fallback configuration for XRPC when service URL is not explicit.
  """

  @default_base_url "https://bsky.social/xrpc"

  @doc """
  Gets the configured base URL or returns the default.
  """
  def get(:base_url) do
    Application.get_env(:proto_rune, :base_url, @default_base_url)
  end

  def get(key) do
    Application.get_env(:proto_rune, key)
  end
end
