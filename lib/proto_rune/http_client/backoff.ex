defmodule ProtoRune.HTTPClient.Backoff do
  @moduledoc """
  Pure helpers to compute retry delays for rate limited (HTTP 429) responses.

  The delay grows exponentially per attempt and is capped by a maximum. When
  the server sends a `Retry-After` header, its value takes precedence over the
  computed backoff.
  """

  @doc """
  Computes the delay in milliseconds to wait before the given retry attempt.

  The first retry attempt is 1. The delay doubles per attempt starting from
  `:base_delay` and never exceeds `:max_delay`. When `:retry_after` (in
  milliseconds) is present, it is returned as-is.

  ## Options

    * `:base_delay` - delay for the first retry, defaults to 500ms
    * `:max_delay` - ceiling for the computed delay, defaults to 10_000ms
    * `:retry_after` - delay in milliseconds parsed from a `Retry-After` header

  ## Examples

      iex> Backoff.delay(1, base_delay: 500, max_delay: 10_000)
      500

      iex> Backoff.delay(3, base_delay: 500, max_delay: 10_000)
      2_000

      iex> Backoff.delay(1, retry_after: 30_000)
      30_000
  """
  def delay(attempt, opts \\ []) when is_integer(attempt) and attempt >= 1 do
    case Keyword.get(opts, :retry_after) do
      retry_after when is_integer(retry_after) and retry_after >= 0 ->
        retry_after

      _ ->
        base_delay = Keyword.get(opts, :base_delay, 500)
        max_delay = Keyword.get(opts, :max_delay, 10_000)

        min(base_delay * Integer.pow(2, attempt - 1), max_delay)
    end
  end

  @doc """
  Extracts the `Retry-After` header of an HTTP response as milliseconds.

  Returns `nil` when the header is absent or cannot be parsed. Handles both
  map headers (as returned by Req) and lists of header tuples.
  """
  def retry_after_ms(%{headers: headers}) when is_map(headers) do
    case Map.fetch(headers, "retry-after") do
      {:ok, [value | _]} -> parse_retry_after(value)
      {:ok, value} when is_binary(value) -> parse_retry_after(value)
      :error -> nil
    end
  end

  def retry_after_ms(%{headers: headers}) when is_list(headers) do
    Enum.find_value(headers, fn
      {name, value} when is_binary(name) and is_binary(value) ->
        if String.downcase(name) == "retry-after", do: parse_retry_after(value)

      _ ->
        nil
    end)
  end

  def retry_after_ms(_response), do: nil

  @doc """
  Parses a `Retry-After` header value into milliseconds.

  Only the delta-seconds form is supported. Returns `nil` for anything else.
  """
  def parse_retry_after(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {seconds, ""} when seconds >= 0 -> seconds * 1_000
      _invalid -> nil
    end
  end

  def parse_retry_after(_value), do: nil
end
