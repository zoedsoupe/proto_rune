defmodule ProtoRune.XRPC.Config do
  @moduledoc """
  Provides fallback configuration for XRPC when service URL is not explicit.
  """

  @default_base_url "https://bsky.social/xrpc"

  @doc """
  The base URL used when neither the query/procedure nor the session
  carries one.
  """
  def default_base_url, do: @default_base_url

  def get(key) do
    Application.get_env(:proto_rune, key)
  end
end
