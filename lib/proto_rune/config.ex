defmodule ProtoRune.Config do
  @moduledoc """
  Configuration for the ProtoRune library.

  ## Service URL precedence

  The XRPC endpoint a request goes to is resolved in this order:

  1. per-call `:service` option (for example on `ProtoRune.login/3`)
  2. the session's own `service_url` (see `ProtoRune.Session.service_url/1`)
  3. the `:base_url` application environment key
  4. the default, `"https://bsky.social/xrpc"`

  ## Application environment

      config :proto_rune,
        base_url: "https://pds.example.com/xrpc",
        rate_limit: [requests_per_minute: 3_000],
        retry: [max_attempts: 3]
  """

  @default_base_url "https://bsky.social/xrpc"

  @doc """
  Gets a configuration value by key.
  """
  def get(key) do
    Application.get_env(:proto_rune, key)
  end

  @doc """
  The XRPC base URL used when neither the call nor the session carries
  one. Reads `config :proto_rune, :base_url`, falling back to
  `"https://bsky.social/xrpc"`.
  """
  def default_base_url do
    get(:base_url) || @default_base_url
  end
end
