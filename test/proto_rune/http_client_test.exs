defmodule ProtoRune.HTTPClientTest do
  use ExUnit.Case, async: false

  alias ProtoRune.HTTPClient

  defmodule FakeAdapter do
    @moduledoc false
    @behaviour ProtoRune.HTTPClient.Adapter

    def start_link(responses) do
      Agent.start_link(fn -> responses end, name: __MODULE__)
    end

    @impl true
    def request(_method, _url, _opts) do
      Agent.get_and_update(__MODULE__, fn
        [next | rest] -> {next, rest}
        [] -> {nil, []}
      end) || raise("FakeAdapter received an unexpected request")
    end
  end

  setup do
    for key <- [:http_client, :retry, :rate_limit] do
      previous = Application.get_env(:proto_rune, key)
      on_exit(fn -> restore_env(key, previous) end)
    end

    Application.put_env(:proto_rune, :http_client, FakeAdapter)
    Application.put_env(:proto_rune, :rate_limit, false)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:proto_rune, key)
  defp restore_env(key, value), do: Application.put_env(:proto_rune, key, value)

  defp start_adapter(responses) do
    {:ok, _pid} = FakeAdapter.start_link(responses)
  end

  defp ok_response, do: {:ok, %{status: 200, headers: %{}, body: %{}}}
  defp rate_limited(headers \\ %{}), do: {:ok, %{status: 429, headers: headers, body: %{}}}

  describe "retry on 429" do
    test "returns successful responses without retrying" do
      start_adapter([ok_response()])

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://example.com/xrpc/test")
    end

    test "retries once and honors the Retry-After header" do
      start_adapter([rate_limited(%{"retry-after" => ["2"]}), ok_response()])

      test_pid = self()
      retry = [sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end]

      assert {:ok, %{status: 200}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: retry)

      assert_received {:slept, 2_000}
    end

    test "backs off exponentially when Retry-After is absent" do
      responses = [rate_limited(), rate_limited(), rate_limited(), ok_response()]
      start_adapter(responses)

      test_pid = self()

      retry = [
        max_attempts: 4,
        base_delay: 100,
        max_delay: 10_000,
        sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end
      ]

      assert {:ok, %{status: 200}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: retry)

      assert_received {:slept, 100}
      assert_received {:slept, 200}
      assert_received {:slept, 400}
    end

    test "caps the backoff at max_delay" do
      responses = [rate_limited(), rate_limited(), ok_response()]
      start_adapter(responses)

      test_pid = self()

      retry = [
        max_attempts: 3,
        base_delay: 5_000,
        max_delay: 8_000,
        sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end
      ]

      assert {:ok, %{status: 200}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: retry)

      assert_received {:slept, 5_000}
      assert_received {:slept, 8_000}
    end

    test "gives up and returns the last response after max_attempts" do
      responses = [rate_limited(), rate_limited(), rate_limited()]
      start_adapter(responses)

      retry = [max_attempts: 2, base_delay: 1, sleep_fun: fn _ms -> :ok end]

      assert {:ok, %{status: 429}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: retry)
    end

    test "does not retry other error statuses" do
      start_adapter([{:ok, %{status: 500, headers: %{}, body: %{}}}])

      retry = [max_attempts: 3, sleep_fun: fn _ms -> raise("must not sleep") end]

      assert {:ok, %{status: 500}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: retry)
    end

    test "does not retry transport errors" do
      start_adapter([{:error, :timeout}])

      retry = [max_attempts: 3, sleep_fun: fn _ms -> raise("must not sleep") end]

      assert {:error, :timeout} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: retry)
    end

    test "reads retry configuration from the application environment" do
      start_adapter([rate_limited(), ok_response()])

      test_pid = self()

      Application.put_env(:proto_rune, :retry,
        max_attempts: 2,
        base_delay: 50,
        sleep_fun: fn ms -> send(test_pid, {:slept, ms}) end
      )

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://example.com/xrpc/test")

      assert_received {:slept, 50}
    end

    test "retry: false disables retries" do
      start_adapter([rate_limited()])

      assert {:ok, %{status: 429}} =
               HTTPClient.request(:get, "https://example.com/xrpc/test", retry: false)
    end
  end

  describe "rate limiting" do
    test "throttles requests per host once the per-minute limit is reached" do
      start_adapter([ok_response(), ok_response(), ok_response()])

      {:ok, clock} = Agent.start_link(fn -> 0 end)

      Application.put_env(:proto_rune, :rate_limit,
        requests_per_minute: 2,
        now_fun: fn -> Agent.get(clock, & &1) end,
        sleep_fun: fn ms -> Agent.update(clock, &(&1 + ms)) end
      )

      url = "https://example.com/xrpc/test"

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url)
      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url)
      assert Agent.get(clock, & &1) == 0

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url)
      assert Agent.get(clock, & &1) == 60_000
    end

    test "tracks different hosts independently" do
      start_adapter([ok_response(), ok_response()])

      Application.put_env(:proto_rune, :rate_limit,
        requests_per_minute: 1,
        sleep_fun: fn _ms -> raise("must not sleep") end
      )

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://one.example.com/xrpc/test")
      assert {:ok, %{status: 200}} = HTTPClient.request(:get, "https://two.example.com/xrpc/test")
    end

    test "rate_limit: false disables throttling per request" do
      start_adapter([ok_response(), ok_response()])

      Application.put_env(:proto_rune, :rate_limit,
        requests_per_minute: 1,
        sleep_fun: fn _ms -> raise("must not sleep") end
      )

      url = "https://example.com/xrpc/test"

      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, rate_limit: false)
      assert {:ok, %{status: 200}} = HTTPClient.request(:get, url, rate_limit: false)
    end
  end
end
