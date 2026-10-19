defmodule ProtoRune.BotTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Bot.Server
  alias ProtoRune.StubServer

  defmodule SessionBot do
    @moduledoc false
    use ProtoRune.Bot, name: __MODULE__, strategy: :polling

    def get_identifier, do: "bot.test"
    def get_password, do: "password"

    def handle_event(:session, _payload, session), do: send(self(), {:got_session, session})

    def handle_event(event, payload, _session), do: handle_event(event, payload)
  end

  # No `use ProtoRune.Bot`, so no handle_event/3 default: dispatch falls back to arity 2.
  defmodule PlainBot do
    @moduledoc false
    @behaviour ProtoRune.Bot

    def get_identifier, do: "bot.test"
    def get_password, do: "password"

    def handle_event(:plain, _payload), do: send(self(), {:got_plain_event})
    def handle_event(_event, _payload), do: :ok
  end

  # Defines the stateful handle_event/4: the server passes the bot state as the
  # fourth argument and stores the return value as the new state.
  defmodule StatefulBot do
    @moduledoc false
    use ProtoRune.Bot, name: __MODULE__, strategy: :polling

    def get_identifier, do: "bot.test"
    def get_password, do: "password"

    def handle_event(:remember, payload, _session, _state), do: {:remembered, payload[:n]}
    def handle_event(:recall, _payload, _session, state), do: state
  end

  # persist_state/1 runs inside the bot server process, so it reports back to the
  # test through a registered name (same approach as the jetstream handler tests).
  defmodule PersistBot do
    @moduledoc false
    use ProtoRune.Bot, name: __MODULE__, strategy: :polling

    def get_identifier, do: "bot.test"
    def get_password, do: "password"

    def init_state, do: %{ticks: 0}

    def persist_state(state) do
      send(:bot_persist_probe, {:persisted, state})
      :ok
    end
  end

  defmodule FailingPersistBot do
    @moduledoc false
    use ProtoRune.Bot, name: __MODULE__, strategy: :polling

    def get_identifier, do: "bot.test"
    def get_password, do: "password"

    def persist_state(_state) do
      send(:bot_persist_error_probe, :persist_called)
      {:error, :boom}
    end
  end

  @session %ProtoRune.Atproto.Session{
    access_jwt: "test-token",
    refresh_jwt: "test-refresh",
    did: "did:plc:test",
    handle: "bot.test"
  }

  test "generates a child spec with the bot name as id" do
    spec = SessionBot.child_spec([])

    assert spec.id == SessionBot
    assert spec.start == {SessionBot, :start_link, []}
  end

  test "dispatches events to handle_event/3 with the session when defined" do
    assert {:noreply, _state} =
             Server.handle_cast({:handle_event, :session, %{}}, %{
               name: SessionBot,
               session: @session
             })

    assert_receive {:got_session, @session}
  end

  test "falls back to handle_event/2 when the bot does not define arity 3" do
    assert {:noreply, _state} =
             Server.handle_cast({:handle_event, :plain, %{}}, %{name: PlainBot, session: @session})

    assert_receive {:got_plain_event}
  end

  test "threads the state through handle_event/4 across events" do
    state = %{name: StatefulBot, session: @session}

    assert {:noreply, state} = Server.handle_cast({:handle_event, :remember, %{n: 1}}, state)
    assert state[:bot_state] == {:remembered, 1}

    assert {:noreply, state} = Server.handle_cast({:handle_event, :recall, %{}}, state)

    # the second dispatch received the state stored by the first one
    assert state[:bot_state] == {:remembered, 1}
  end

  test "keeps the bot state nil when only handle_event/3 is defined" do
    assert {:noreply, state} =
             Server.handle_cast({:handle_event, :session, %{}}, %{name: SessionBot, session: @session})

    assert state[:bot_state] == nil
  end

  test "accepts an optional :persist_interval option" do
    opts = Server.options_t!(name: StatefulBot, module: StatefulBot, strategy: :polling, persist_interval: 30)
    assert opts[:persist_interval] == 30

    opts = Server.options_t!(name: StatefulBot, module: StatefulBot, strategy: :polling)
    assert opts[:persist_interval] == nil
  end

  @pds_did "did:plc:test"

  describe "optional state persistence" do
    test "seeds the state from init_state/0 and persists it on each tick" do
      Process.register(self(), :bot_persist_probe)
      {:ok, server} = StubServer.open()
      stub_pds(server)
      start_bot(server, PersistBot, persist_interval: 1)

      # the first tick carries the state seeded by init_state/0
      assert_eventually(fn -> match?({:ok, %{ticks: 0}}, receive_persisted()) end, 60)

      # the tick reschedules itself: a second one arrives without any new event
      assert_eventually(fn -> receive_persisted() != nil end, 60)
    end

    test "tolerates a persist_state/1 that returns an error" do
      Process.register(self(), :bot_persist_error_probe)
      {:ok, server} = StubServer.open()
      stub_pds(server)
      {name, pid} = start_bot(server, FailingPersistBot, persist_interval: 1)

      assert_eventually(fn -> receive_persist_called() == :ok end, 60)
      assert_eventually(fn -> receive_persist_called() == :ok end, 60)

      # the error is logged, never fatal
      assert Process.alive?(pid)
      assert Process.whereis(name) == pid
    end
  end

  defp stub_pds(server) do
    json = fn body -> {200, [{"content-type", "application/json"}], JSON.encode!(body)} end

    StubServer.expect(server, "POST", "/xrpc/com.atproto.server.createSession", fn _req ->
      json.(%{"accessJwt" => "access", "refreshJwt" => "refresh", "handle" => "bot.test", "did" => @pds_did})
    end)

    StubServer.expect(server, "GET", "/xrpc/app.bsky.actor.getProfile", fn _req ->
      json.(%{"did" => @pds_did, "handle" => "bot.test"})
    end)

    StubServer.expect(server, "GET", "/xrpc/app.bsky.notification.listNotifications", fn _req ->
      json.(%{"notifications" => [], "cursor" => nil})
    end)
  end

  defp start_bot(server, module, extra_opts) do
    opts =
      [
        name: :"bot_#{System.unique_integer([:positive])}",
        module: module,
        strategy: :polling,
        polling: %{interval: 60},
        service: server.url,
        identifier: "bot.test",
        password: "password"
      ] ++ extra_opts

    pid = start_supervised!({Server, opts})
    {opts[:name], pid}
  end

  # Drains one persisted report from the mailbox; nil leaves the test waiting on
  # the next assert_eventually attempt.
  defp receive_persisted do
    receive do
      {:persisted, state} -> {:ok, state}
    after
      0 -> nil
    end
  end

  defp receive_persist_called do
    receive do
      :persist_called -> :ok
    after
      0 -> nil
    end
  end

  # Same helper as the session manager tests: the persistence tick arrives
  # asynchronously from the bot server process.
  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      if attempts == 0 do
        flunk("condition not met in time")
      else
        Process.sleep(50)
        assert_eventually(fun, attempts - 1)
      end
    end
  end
end
