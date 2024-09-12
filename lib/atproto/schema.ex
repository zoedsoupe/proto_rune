defmodule Atproto.Schema do
  @moduledoc false

  use XRPC.DSL

  defprocedure "com.atproto.server.createSession" do
    param(:identifier, {:required, :string})
    param(:password, {:required, :string})
  end
end
