defmodule ProtoRune.HTTPClientTest do
  use ProtoRune.TestCase, async: false

  alias ProtoRune.HTTPClient

  setup do
    put_env(:rate_limit, false)
    :ok
  end

  defp ok_response, do: {:ok, %{status: 200, headers: %{}, body: %{}}}
  defp rate_limited(headers \\ %{}), do: {:ok, %{status: 429, headers: headers, body: %{}}}

  describe "retry on 429" do
    test "returns successful responses without retrying" do
      http = fake_http_from([ok_response()])

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://example.com/xrpc/test", http)
    end

    test "retries once and honors the Retry-After header" do
      http = fake_http_from([rate_limited(%{"retry-after" => ["2"]}), ok_response()])

      test_pid = self()
      retry = [sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end]

      assert {:ok, %{status: 200}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, retry} | http])

      assert_received {:slept, 2_000}
    end

    test "backs off exponentially when Retry-After is absent" do
      http = fake_http_from([rate_limited(), rate_limited(), rate_limited(), ok_response()])

      test_pid = self()

      retry = [
        max_attempts: 4,
        base_delay: 100,
        max_delay: 10_000,
        sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end
      ]

      assert {:ok, %{status: 200}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, retry} | http])

      assert_received {:slept, 100}
      assert_received {:slept, 200}
      assert_received {:slept, 400}
    end

    test "caps the backoff at max_delay" do
      http = fake_http_from([rate_limited(), rate_limited(), ok_response()])

      test_pid = self()

      retry = [
        max_attempts: 3,
        base_delay: 5_000,
        max_delay: 8_000,
        sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end
      ]

      assert {:ok, %{status: 200}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, retry} | http])

      assert_received {:slept, 5_000}
      assert_received {:slept, 8_000}
    end

    test "gives up and returns the last response after max_attempts" do
      http = fake_http_from([rate_limited(), rate_limited(), rate_limited()])

      retry = [max_attempts: 2, base_delay: 1, sleep_fun: fn _ms -> :ok end]

      assert {:ok, %{status: 429}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, retry} | http])
    end

    test "does not retry other error statuses" do
      http = fake_http_from([{:ok, %{status: 500, headers: %{}, body: %{}}}])

      retry = [max_attempts: 3, sleep_fun: fn _ms -> raise("must not sleep") end]

      assert {:ok, %{status: 500}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, retry} | http])
    end

    test "does not retry transport errors" do
      http = fake_http_from([{:error, :timeout}])

      retry = [max_attempts: 3, sleep_fun: fn _ms -> raise("must not sleep") end]

      assert {:error, :timeout} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, retry} | http])
    end

    test "reads retry configuration from the application environment" do
      http = [rate_limited(), ok_response()] |> fake_http_from() |> Keyword.delete(:retry)

      test_pid = self()

      put_env(:retry,
        max_attempts: 2,
        base_delay: 50,
        sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end
      )

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://example.com/xrpc/test", http)

      assert_received {:slept, 50}
    end

    test "retry: false disables retries" do
      http = fake_http_from([rate_limited()])

      assert {:ok, %{status: 429}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", [{:retry, false} | http])
    end
  end

  describe "rate limiting" do
    test "throttles requests per host once the per-minute limit is reached" do
      http = fake_http_from([ok_response(), ok_response(), ok_response()])

      {:ok, clock} = Agent.start_link(fn -> 0 end)

      put_env(:rate_limit,
        requests_per_minute: 2,
        now_fun: fn -> Agent.get(clock, & &1) end,
        sleep_fun: fn ms -> Agent.update(clock, &(&1 + ms)) end
      )

      url = "https://example.com/xrpc/test"

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, http)
      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, http)
      assert Agent.get(clock, & &1) == 0

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, http)
      assert Agent.get(clock, & &1) == 60_000
    end

    test "tracks different hosts independently" do
      http = fake_http_from([ok_response(), ok_response()])

      put_env(:rate_limit,
        requests_per_minute: 1,
        sleep_fun: fn _ms -> raise("must not sleep") end
      )

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://one.example.com/xrpc/test", http)
      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://two.example.com/xrpc/test", http)
    end

    test "rate_limit: false disables throttling per request" do
      http = fake_http_from([ok_response(), ok_response()])

      put_env(:rate_limit,
        requests_per_minute: 1,
        sleep_fun: fn _ms -> raise("must not sleep") end
      )

      url = "https://example.com/xrpc/test"

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, [{:rate_limit, false} | http])
      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, [{:rate_limit, false} | http])
    end
  end
end
