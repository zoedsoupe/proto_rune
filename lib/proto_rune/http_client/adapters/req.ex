defmodule ProtoRune.HTTPClient.Adapters.Req do
  @moduledoc """
  The `HTTPClient.Adapters.Req` module provides an adapter for the Req library. It implements the `HTTPClient.Adapter` behaviour and defines the `request/3` function to make HTTP requests using Req.
  """

  @behaviour ProtoRune.HTTPClient.Adapter

  @impl true
  def request(method, url, opts) do
    {timeout, opts} = Keyword.split(opts, [:timeout])

    [
      method: method,
      url: url,
      connect_options: [timeout: timeout[:timeout]]
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.request()
  end
end
