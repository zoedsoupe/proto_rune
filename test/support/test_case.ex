defmodule ProtoRune.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import ProtoRune.TestCase
    end
  end

  @doc """
  Sets a `:proto_rune` application env key, restoring the previous value on test exit.
  """
  def put_env(key, value) do
    previous = Application.get_env(:proto_rune, key)

    ExUnit.Callbacks.on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:proto_rune, key),
        else: Application.put_env(:proto_rune, key, previous)
    end)

    Application.put_env(:proto_rune, key, value)
  end

  @doc """
  Builds `:http` options routing requests through `ProtoRune.FakeAdapter`
  with the given `fn method, url, opts -> response` handler, retries
  disabled. Pass as the `:http` option of any API call:

      Bsky.post(session, "hi", http: fake_http(fn :post, _url, _opts -> ... end))
  """
  def fake_http(handler) when is_function(handler, 3) do
    [adapter: ProtoRune.FakeAdapter, handler: handler, retry: false]
  end

  @doc """
  Same as `fake_http/1`, but consumes the given responses in FIFO order
  and raises on unexpected requests.
  """
  def fake_http_from(responses) when is_list(responses) do
    {:ok, agent} = Agent.start_link(fn -> responses end)

    fake_http(fn _method, _url, _opts ->
      Agent.get_and_update(agent, fn
        [next | rest] -> {next, rest}
        [] -> {nil, []}
      end) || raise("ProtoRune.FakeAdapter received an unexpected request")
    end)
  end
end
