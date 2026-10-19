defmodule ProtoRune.Bot.JetstreamTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Bot.Jetstream

  defmodule FakeTransport do
    @moduledoc false

    @behaviour ProtoRune.Firehose.Transport

    @impl true
    def connect(url, opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      send(test_pid, {:jetstream_connected, url})
      {:ok, %{test_pid: test_pid}}
    end

    @impl true
    def stream(state, {:fake_frame, data}), do: {:ok, state, [{:text, data}]}
    def stream(state, :fake_close), do: {:ok, state, [:closed]}
    def stream(_state, _message), do: :unknown

    @impl true
    def close(_state), do: :ok
  end

  @commit """
  {
    "did": "did:plc:hoyoz2vqz74upepwfqoxcooz",
    "time_us": 1725516133891108,
    "kind": "commit",
    "commit": {
      "rev": "3l3qo2vutsw2b",
      "operation": "create",
      "collection": "place.quintal.feed.prosa",
      "rkey": "3l3qo2vutsw2b",
      "record": {"$type": "place.quintal.feed.prosa", "texto": "quintal na janela"},
      "cid": "bafyreidfayvfuwqa7qlnopdijqnbxs35ujtl4q3xnglbg5qdt5edv74zxq"
    }
  }
  """

  @identity """
  {
    "did": "did:plc:hoyoz2vqz74upepwfqoxcooz",
    "time_us": 1725516135231968,
    "kind": "identity",
    "identity": {"did": "did:plc:hoyoz2vqz74upepwfqoxcooz", "handle": "quintal.blog.br", "seq": 1096, "time": "2024-09-05T06:02:15.231Z"}
  }
  """

  defp start_bot_jetstream(opts) do
    [
      name: :"bot_jetstream_#{System.unique_integer([:positive])}",
      server_pid: self(),
      transport: FakeTransport,
      transport_opts: [test_pid: self()],
      backoff_initial: 10,
      backoff_max: 50
    ]
    |> Keyword.merge(opts)
    |> Jetstream.start_link()
  end

  defp frame(data), do: {:fake_frame, data}

  test "connects to the subscribe endpoint of the relay" do
    {:ok, _pid} = start_bot_jetstream(relay: "wss://jetstream.example.com")

    assert_receive {:jetstream_connected, url}
    assert url == "wss://jetstream.example.com/subscribe"
  end

  test "passes wanted collections and dids as query parameters" do
    {:ok, _pid} =
      start_bot_jetstream(
        wanted_collections: ["place.quintal.feed.prosa"],
        wanted_dids: ["did:plc:hoyoz2vqz74upepwfqoxcooz"]
      )

    assert_receive {:jetstream_connected, url}
    assert url =~ "wantedCollections=place.quintal.feed.prosa"
    assert url =~ "wantedDids=did%3Aplc%3Ahoyoz2vqz74upepwfqoxcooz"
  end

  test "dispatches a commit event to the bot server" do
    {:ok, pid} = start_bot_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(pid, frame(@commit))

    assert_receive {:handle_event, :commit, payload}
    assert payload.repo == "did:plc:hoyoz2vqz74upepwfqoxcooz"
    assert payload.rev == "3l3qo2vutsw2b"
    assert payload.seq == 1_725_516_133_891_108
    assert %DateTime{} = payload.time
    assert payload.action == :create
    assert payload.path == "place.quintal.feed.prosa/3l3qo2vutsw2b"
    assert payload.cid == "bafyreidfayvfuwqa7qlnopdijqnbxs35ujtl4q3xnglbg5qdt5edv74zxq"
    assert payload.record["texto"] == "quintal na janela"
  end

  test "dispatches delete operations without a record" do
    {:ok, pid} = start_bot_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(
      pid,
      frame(
        ~s({"did": "did:plc:x", "time_us": 1, "kind": "commit", "commit": {"rev": "r", "operation": "delete", "collection": "app.bsky.feed.post", "rkey": "k"}})
      )
    )

    assert_receive {:handle_event, :commit, payload}
    assert payload.action == :delete
    assert payload.path == "app.bsky.feed.post/k"
    assert payload.cid == nil
    assert payload.record == nil
  end

  test "dispatches non-commit events with the raw payload" do
    {:ok, pid} = start_bot_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(pid, frame(@identity))

    assert_receive {:handle_event, :identity, payload}
    assert payload.repo == "did:plc:hoyoz2vqz74upepwfqoxcooz"
    assert payload.seq == 1_725_516_135_231_968
    assert %DateTime{} = payload.time
    assert payload.payload["identity"]["handle"] == "quintal.blog.br"
  end

  test "tracks the time_us of the last delivered event" do
    {:ok, pid} = start_bot_jetstream([])
    assert_receive {:jetstream_connected, _url}
    assert Jetstream.cursor(pid) == nil

    send(pid, frame(@commit))

    assert_receive {:handle_event, :commit, %{seq: time_us}}
    assert Jetstream.cursor(pid) == time_us
  end

  test "reconnects after a connection failure, resuming from the last cursor" do
    {:ok, pid} = start_bot_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(pid, frame(@commit))
    assert_receive {:handle_event, :commit, %{seq: time_us}}

    send(pid, :fake_close)

    assert_receive {:jetstream_connected, url}
    assert url =~ "cursor=#{time_us}"
    assert Process.alive?(pid)
  end
end
