defmodule ProtoRune.BotTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Bot.Server

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
end
