defmodule ProtoRune.Bot.TelemetryTest do
  use ExUnit.Case, async: false

  alias ProtoRune.Bot.Poller
  alias ProtoRune.Bot.Server

  @events [
    [:proto_rune, :bot, :event, :start],
    [:proto_rune, :bot, :event, :stop],
    [:proto_rune, :bot, :event, :exception],
    [:proto_rune, :bot, :event, :dispatch],
    [:proto_rune, :bot, :poll, :start],
    [:proto_rune, :bot, :poll, :stop],
    [:proto_rune, :bot, :poll, :exception],
    [:proto_rune, :bot, :rate_limited]
  ]

  defmodule TestBot do
    @moduledoc false
    @behaviour ProtoRune.Bot

    @impl true
    def handle_event(:boom, _payload), do: raise("boom")
    def handle_event(_event, _payload), do: :ok
  end

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
    Application.put_env(:proto_rune, :retry, false)

    test_pid = self()
    handler_id = "bot-telemetry-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:proto_rune, key)
  defp restore_env(key, value), do: Application.put_env(:proto_rune, key, value)

  describe "event processing" do
    test "emits a dispatch count and start/stop around handle_event/2" do
      assert {:noreply, _state} =
               Server.handle_cast({:handle_event, :mention, %{uri: "at://did:plc:1234"}}, %{
                 name: TestBot
               })

      assert_receive {:telemetry_event, [:proto_rune, :bot, :event, :dispatch], %{count: 1},
                      %{bot: TestBot, event: :mention}}

      assert_receive {:telemetry_event, [:proto_rune, :bot, :event, :start], %{system_time: _},
                      %{bot: TestBot, event: :mention}}

      assert_receive {:telemetry_event, [:proto_rune, :bot, :event, :stop], %{duration: duration},
                      %{bot: TestBot, event: :mention}}

      assert is_integer(duration)
    end

    test "dispatch events carry the event type for distribution counts" do
      Server.handle_cast({:handle_event, :like, %{}}, %{name: TestBot})
      Server.handle_cast({:handle_event, :like, %{}}, %{name: TestBot})
      Server.handle_cast({:handle_event, :follow, %{}}, %{name: TestBot})

      events =
        for _ <- 1..3 do
          assert_receive {:telemetry_event, [:proto_rune, :bot, :event, :dispatch], %{count: 1}, %{event: event}}

          event
        end

      assert Enum.frequencies(events) == %{like: 2, follow: 1}
    end

    test "emits an exception event when the handler raises" do
      assert_raise RuntimeError, "boom", fn ->
        Server.handle_cast({:handle_event, :boom, %{}}, %{name: TestBot})
      end

      assert_receive {:telemetry_event, [:proto_rune, :bot, :event, :exception], %{duration: _duration}, metadata}

      assert metadata.bot == TestBot
      assert metadata.event == :boom
      assert metadata.kind == :error
      assert %RuntimeError{message: "boom"} = metadata.reason
    end
  end

  describe "polling" do
    test "emits poll start/stop around each polling cycle" do
      start_poller([ok_notifications()])

      assert_receive {:telemetry_event, [:proto_rune, :bot, :poll, :start], %{system_time: _}, %{poller: poller}}

      assert_receive {:telemetry_event, [:proto_rune, :bot, :poll, :stop], %{duration: duration}, %{poller: ^poller}}

      assert is_integer(duration)
    end

    test "emits a rate_limited event when the API responds with 429" do
      start_poller([rate_limited(%{"retry-after" => ["30"]})])

      assert_receive {:telemetry_event, [:proto_rune, :bot, :rate_limited], %{count: 1}, metadata}

      assert metadata.attempt == 1
      assert metadata.retry_in == 30_000
      assert is_atom(metadata.poller)
    end
  end

  defp start_poller(responses) do
    {:ok, _pid} = FakeAdapter.start_link(responses)

    name = :"poller_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Poller,
       [
         name: name,
         interval: 60,
         process_from: NaiveDateTime.utc_now(),
         session: %{access_jwt: "test-token"},
         server_pid: self()
       ]}
    )

    name
  end

  defp ok_notifications do
    {:ok, %{status: 200, headers: %{}, body: %{"notifications" => [], "cursor" => "cursor-1"}}}
  end

  defp rate_limited(headers) do
    {:ok, %Req.Response{status: 429, headers: headers, body: %{}}}
  end
end
