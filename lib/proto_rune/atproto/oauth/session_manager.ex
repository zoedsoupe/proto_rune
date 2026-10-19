defmodule ProtoRune.Atproto.OAuth.SessionManager do
  @moduledoc """
  Deprecated. Use `ProtoRune.SessionManager` instead.

  The generic manager now also handles the behaviour this module used to
  own: revocation on `logout/1`, `invalid_grant` handling and persistence
  across restarts. `start_link/1` still accepts the options published
  before 0.6.0 (`:client` and `:http` at the top level are translated
  into `:refresh_opts`), and `session/1` and `logout/1` are forwarded.

  This module will be removed in 1.0.
  """

  @doc """
  Starts a session manager. Accepts the same options as
  `ProtoRune.SessionManager.start_link/1`, with the OAuth client and the
  HTTP options at the top level instead of inside `:refresh_opts`.
  """
  @deprecated "use ProtoRune.SessionManager with refresh_opts: [client: client]"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    client = Keyword.fetch!(opts, :client)
    http = Keyword.get(opts, :http)

    refresh_opts =
      opts
      |> Keyword.get(:refresh_opts, [])
      |> Keyword.put(:client, client)
      |> maybe_put_http(http)

    opts
    |> Keyword.put(:refresh_opts, refresh_opts)
    |> ProtoRune.SessionManager.start_link()
  end

  @doc """
  Returns the session currently held by `server`. See
  `ProtoRune.SessionManager.session/1`.
  """
  @deprecated "use ProtoRune.SessionManager.session/1"
  defdelegate session(server), to: ProtoRune.SessionManager

  @doc """
  Revokes the session, deletes it from the store and stops the manager.
  See `ProtoRune.SessionManager.logout/1`.
  """
  @deprecated "use ProtoRune.SessionManager.logout/1"
  defdelegate logout(server), to: ProtoRune.SessionManager

  defp maybe_put_http(refresh_opts, nil), do: refresh_opts
  defp maybe_put_http(refresh_opts, http), do: Keyword.put(refresh_opts, :http, http)
end
