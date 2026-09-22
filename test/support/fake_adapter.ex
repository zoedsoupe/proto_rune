defmodule ProtoRune.FakeAdapter do
  @moduledoc false
  @behaviour ProtoRune.HTTPClient.Adapter

  # The handler travels in the request opts, so no global state is needed
  # and tests stay async. See ProtoRune.TestCase.fake_http/1.
  @impl true
  def request(method, url, opts) do
    Keyword.fetch!(opts, :handler).(method, url, opts)
  end
end
