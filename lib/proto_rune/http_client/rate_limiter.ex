defmodule ProtoRune.HTTPClient.RateLimiter do
  @moduledoc """
  Tracks outgoing requests per key (usually the target host) in fixed
  one-minute windows and throttles callers once a configurable limit is
  reached.

  Counts are kept in an ETS table so no process needs to be started. When the
  limit for the current window is exceeded, the caller sleeps until the next
  window starts.
  """

  @table __MODULE__
  @window_ms 60_000

  @doc """
  Registers a request for `key`, sleeping until the next window when the
  per-minute limit for the current window has been reached.

  ## Options

    * `:requests_per_minute` - the limit for `key`. `nil` or `false` disables
      throttling and tracking.
    * `:now_fun` - zero-arity function returning the current time in
      milliseconds. Defaults to `System.monotonic_time/1`.
    * `:sleep_fun` - one-arity function used to wait, defaults to
      `Process.sleep/1`.

  Returns `:ok` once the request may proceed.
  """
  def await_turn(key, opts \\ []) do
    case Keyword.get(opts, :requests_per_minute) do
      limit when is_integer(limit) and limit > 0 -> throttle(key, limit, opts)
      _disabled -> :ok
    end
  end

  defp throttle(key, limit, opts) do
    ensure_table()

    now_fun = Keyword.get(opts, :now_fun, fn -> System.monotonic_time(:millisecond) end)
    sleep_fun = Keyword.get(opts, :sleep_fun, &Process.sleep/1)

    now = now_fun.()
    window = div(now, @window_ms)
    bucket = {key, window}

    count = :ets.update_counter(@table, bucket, {2, 1}, {bucket, 0})

    if count > limit do
      sleep_fun.((window + 1) * @window_ms - now)
      throttle(key, limit, opts)
    else
      prune(key, window)
      :ok
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _tid -> @table
    end
  rescue
    ArgumentError -> @table
  end

  defp prune(key, window) do
    :ets.select_delete(@table, [{{{key, :"$1"}, :_}, [{:<, :"$1", window - 1}], [true]}])
    :ok
  end
end
