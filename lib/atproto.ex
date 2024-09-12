defmodule Atproto do
  @moduledoc false

  alias Atproto.Schema
  alias XRPC.Client
  alias XRPC.Procedure

  def create_session(identifier: identifier, password: password)
      when is_binary(identifier) and is_binary(password) do
    proc = Schema.procedure("com.atproto.server.createSession")
    body = %{identifier: identifier, password: password}

    with {:ok, proc} <- Procedure.put_body(proc, body) do
      Client.execute(proc)
    end
  end
end
