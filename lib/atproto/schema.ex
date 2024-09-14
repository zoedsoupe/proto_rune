defmodule Atproto.Schema do
  @moduledoc false

  use XRPC.DSL

  @doc """
  Create an authentication session.

  https://docs.bsky.app/docs/api/com-atproto-server-create-session
  """
  defprocedure "com.atproto.server.createSession", for: :todo do
    param(:identifier, {:required, :string})
    param(:password, {:required, :string})
  end
end
