defmodule ProtoRune.HTTPClient.RateLimiterTest do
  use ExUnit.Case, async: false

  alias ProtoRune.HTTPClient.RateLimiter

  setup do
    {:ok, clock} = Agent.start_link(fn -> 0 end)

    now_fun = fn -> Agent.get(clock, & &1) end
    sleep_fun = fn ms -> Agent.update(clock, &(&1 + ms)) end

    {:ok, key: {:test, make_ref()}, clock: clock, now_fun: now_fun, sleep_fun: sleep_fun}
  end

  test "allows requests under the limit", %{key: key, now_fun: now_fun, sleep_fun: sleep_fun} do
    for _ <- 1..5 do
      assert :ok =
               RateLimiter.await_turn(key,
                 requests_per_minute: 5,
                 now_fun: now_fun,
                 sleep_fun: sleep_fun
               )
    end
  end

  test "sleeps until the next window once the limit is reached", %{
    key: key,
    clock: clock,
    now_fun: now_fun,
    sleep_fun: sleep_fun
  } do
    opts = [requests_per_minute: 3, now_fun: now_fun, sleep_fun: sleep_fun]

    for _ <- 1..3, do: RateLimiter.await_turn(key, opts)

    assert Agent.get(clock, & &1) == 0

    assert :ok = RateLimiter.await_turn(key, opts)
    assert Agent.get(clock, & &1) == 60_000
  end

  test "tracks keys independently", %{now_fun: now_fun, sleep_fun: sleep_fun} do
    opts = [requests_per_minute: 1, now_fun: now_fun, sleep_fun: sleep_fun]

    assert :ok = RateLimiter.await_turn({:test, make_ref()}, opts)
    assert :ok = RateLimiter.await_turn({:test, make_ref()}, opts)
  end

  test "does not track when disabled", %{key: key} do
    assert :ok = RateLimiter.await_turn(key, requests_per_minute: nil)
    assert :ok = RateLimiter.await_turn(key, requests_per_minute: false)
  end
end
