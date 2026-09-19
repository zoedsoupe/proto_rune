defmodule ProtoRune.Bsky.Labeler do
  @moduledoc """
  Labeler endpoints of the Bluesky lexicon (`app.bsky.labeler.*`).

  Generated XRPC functions; call them as `Labeler.endpoint(session, %{param: value})`.
  """

  import ProtoRune.XRPC.DSL

  @doc """
  Get information about a list of labeler services.

  https://docs.bsky.app/docs/api/app-bsky-labeler-get-services
  """
  defquery "app.bsky.labeler.getServices", for: :todo do
    param :dids, {:required, {:list, :string}}
    param :detailed, :boolean
  end
end
