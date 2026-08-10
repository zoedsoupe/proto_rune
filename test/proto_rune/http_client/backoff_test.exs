defmodule ProtoRune.HTTPClient.BackoffTest do
  use ExUnit.Case, async: true

  alias ProtoRune.HTTPClient.Backoff

  describe "delay/2" do
    test "grows exponentially from the base delay" do
      assert Backoff.delay(1, base_delay: 500, max_delay: 10_000) == 500
      assert Backoff.delay(2, base_delay: 500, max_delay: 10_000) == 1_000
      assert Backoff.delay(3, base_delay: 500, max_delay: 10_000) == 2_000
      assert Backoff.delay(4, base_delay: 500, max_delay: 10_000) == 4_000
    end

    test "is capped by the max delay" do
      assert Backoff.delay(10, base_delay: 500, max_delay: 10_000) == 10_000
    end

    test "uses default delays when not given" do
      assert Backoff.delay(1) == 500
      assert Backoff.delay(2) == 1_000
    end

    test "honors retry_after over the computed backoff" do
      assert Backoff.delay(1, base_delay: 500, retry_after: 30_000) == 30_000
      assert Backoff.delay(1, base_delay: 500, retry_after: 0) == 0
    end
  end

  describe "parse_retry_after/1" do
    test "parses delta-seconds into milliseconds" do
      assert Backoff.parse_retry_after("120") == 120_000
      assert Backoff.parse_retry_after("0") == 0
      assert Backoff.parse_retry_after(" 5 ") == 5_000
    end

    test "returns nil for invalid values" do
      assert Backoff.parse_retry_after("soon") == nil
      assert Backoff.parse_retry_after("-5") == nil
      assert Backoff.parse_retry_after(nil) == nil
    end
  end

  describe "retry_after_ms/1" do
    test "reads map headers with list values" do
      response = %{headers: %{"retry-after" => ["2"]}}
      assert Backoff.retry_after_ms(response) == 2_000
    end

    test "reads map headers with binary values" do
      response = %{headers: %{"retry-after" => "3"}}
      assert Backoff.retry_after_ms(response) == 3_000
    end

    test "reads list headers case-insensitively" do
      response = %{headers: [{"Retry-After", "1"}]}
      assert Backoff.retry_after_ms(response) == 1_000
    end

    test "returns nil when the header is absent or invalid" do
      assert Backoff.retry_after_ms(%{headers: %{}}) == nil
      assert Backoff.retry_after_ms(%{headers: %{"retry-after" => ["nope"]}}) == nil
      assert Backoff.retry_after_ms(%{}) == nil
    end
  end
end
