defmodule ProtoRune.HTTPClient do
  @moduledoc """
  The `HTTPClient` module handles HTTP requests to external services. It provides a simple interface for making GET and POST requests and handling responses.

  ## Rate limiting and retries

  Requests are transparently throttled and retried at the transport layer:

    * requests are tracked per host in one-minute windows; once the
      configured limit is reached the caller sleeps until the next window
    * responses with status 429 are retried with exponential backoff,
      honoring the `Retry-After` header when present

  Configuration is read from the application environment:

      config :proto_rune, :rate_limit,
        requests_per_minute: 3_000

      config :proto_rune, :retry,
        max_attempts: 3,
        base_delay: 500,
        max_delay: 10_000

  Both can also be given per request through the `:rate_limit` and `:retry`
  options of `request/3`, or disabled with `false`:

      HTTPClient.request(:get, url, retry: [max_attempts: 1])
      HTTPClient.request(:get, url, rate_limit: false)

  The `:adapter` option overrides the configured adapter for a single
  request:

      HTTPClient.request(:get, url, adapter: MyApp.HTTPStub)

  Retry options:

    * `:max_attempts` - total attempts, including the first one (default 3)
    * `:base_delay` - backoff delay for the first retry in ms (default 500)
    * `:max_delay` - ceiling for the backoff delay in ms (default 10_000)
    * `:sleep_fun` - one-arity function used to wait between attempts,
      defaults to `Process.sleep/1`
  """

  alias ProtoRune.Config
  alias ProtoRune.HTTPClient.Adapters
  alias ProtoRune.HTTPClient.Backoff
  alias ProtoRune.HTTPClient.RateLimiter

  @default_retry [max_attempts: 3, base_delay: 500, max_delay: 10_000]
  @default_requests_per_minute 3_000

  defp impl(nil), do: Config.get(:http_client) || Adapters.Req
  defp impl(adapter), do: adapter

  def request(method, url, opts \\ []) do
    {adapter, opts} = Keyword.pop(opts, :adapter)
    {retry_opts, opts} = Keyword.pop(opts, :retry, [])
    {rate_limit_opts, opts} = Keyword.pop(opts, :rate_limit, [])

    url
    |> host_key()
    |> RateLimiter.await_turn(rate_limit_config(rate_limit_opts))

    do_request(method, url, opts, retry_config(retry_opts), 1, adapter)
  end

  defp do_request(method, url, opts, retry, attempt, adapter) do
    case impl(adapter).request(method, url, opts) do
      {:ok, %{status: 429} = response} = result ->
        if attempt < retry[:max_attempts] do
          delay =
            Backoff.delay(attempt,
              base_delay: retry[:base_delay],
              max_delay: retry[:max_delay],
              retry_after: Backoff.retry_after_ms(response)
            )

          retry[:sleep_fun].(delay)
          do_request(method, url, opts, retry, attempt + 1, adapter)
        else
          result
        end

      other ->
        other
    end
  end

  defp retry_config(false), do: Keyword.put(@default_retry, :max_attempts, 1)

  defp retry_config(overrides) do
    case Config.get(:retry) do
      false ->
        retry_config(false)

      config ->
        @default_retry
        |> Keyword.merge(config || [])
        |> Keyword.merge(overrides)
        |> Keyword.put_new(:sleep_fun, &Process.sleep/1)
    end
  end

  defp rate_limit_config(false), do: [requests_per_minute: nil]

  defp rate_limit_config(overrides) do
    case Config.get(:rate_limit) do
      false ->
        rate_limit_config(false)

      config ->
        [requests_per_minute: @default_requests_per_minute]
        |> Keyword.merge(config || [])
        |> Keyword.merge(overrides)
    end
  end

  defp host_key(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _uri -> url
    end
  end

  @doc """
  Reads a header value from a response headers collection,
  case-insensitively.

  Adapters deliver headers either as a list of `{name, value}` tuples or
  as a map of downcased names to value lists (Req); both shapes are
  accepted. Returns `nil` when the header is absent.
  """
  @spec get_header(term(), String.t()) :: String.t() | nil
  def get_header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value
    end)
  end

  def get_header(headers, name) when is_map(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: value |> List.wrap() |> List.first()
    end)
  end

  def get_header(_headers, _name), do: nil
end
