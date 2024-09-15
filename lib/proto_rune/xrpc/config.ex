defmodule ProtoRune.XRPC.Config do
  @moduledoc false

  def get(key) when is_atom(key) do
    env = Application.get_env(:proto_rune, :env, :dev)

    xrpc_config(env, key)
  end

  @dev_config [
    base_url: "https://bsky.social/xrpc"
  ]

  defp xrpc_config(:dev, key) do
    Keyword.get(@dev_config, key)
  end

  defp xrpc_config(:prod, key) do
    Application.get_env(:proto_rune, key)
  end
end
