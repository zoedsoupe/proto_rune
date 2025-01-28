defmodule ProtoRune.HTTPClient.Adapter do
  @moduledoc """
  The `HTTPClient.Adapter` module provides an adapter interface for HTTP clients. It defines the behaviour that must be implemented by any HTTP client adapter.
  """

  @callback request(method :: atom(), url :: String.t(), opts :: Keyword.t()) ::
              {:ok, term} | {:error, term}
end
