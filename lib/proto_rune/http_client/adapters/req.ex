defmodule ProtoRune.HTTPClient.Adapters.Req do
  @moduledoc """
  The `HTTPClient.Adapters.Req` module provides an adapter for the Req library. It implements the `HTTPClient.Adapter` behaviour and defines the `request/3` function to make HTTP requests using Req.
  """

  @behaviour ProtoRune.HTTPClient.Adapter

  @impl true
  def request(method, url, opts) do
    {timeout, opts} = Keyword.split(opts, [:timeout])

    connect_options =
      case timeout[:timeout] do
        nil -> []
        ms -> [timeout: ms]
      end

    Req.request(
      [method: method, url: url, decode_body: false, connect_options: connect_options],
      opts
    )
  end
end
