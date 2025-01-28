defmodule ProtoRune.HTTPClient do
  @moduledoc """
  The `HTTPClient` module handles HTTP requests to external services. It provides a simple interface for making GET and POST requests and handling responses.
  """

  alias ProtoRune.Config
  alias ProtoRune.HTTPClient.Adapters

  defp impl do
    Config.get(:http_client) || Adapters.Req
  end

  def request(method, url, opts \\ []) do
    impl().request(method, url, opts)
  end
end
