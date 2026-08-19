defmodule ProtoRune.JetstreamTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Jetstream
  alias ProtoRune.Jetstream.Event

  defmodule FakeTransport do
    @moduledoc false

    @behaviour ProtoRune.Firehose.Transport

    @impl true
    def connect(url, opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)

      if fail_connect?(opts) do
        send(test_pid, :jetstream_connect_failed)
        {:error, :econnrefused}
      else
        send(test_pid, {:jetstream_connected, url})
        {:ok, %{test_pid: test_pid}}
      end
    end

    @impl true
    def stream(state, {:fake_frame, data}), do: {:ok, state, [{:text, data}]}
    def stream(state, :fake_close), do: {:ok, state, [:closed]}
    def stream(state, :fake_error), do: {:error, state, :boom}
    def stream(_state, _message), do: :unknown

    @impl true
    def close(_state), do: :ok

    defp fail_connect?(opts) do
      case Keyword.get(opts, :fail_once) do
        nil -> false
        counter -> :atomics.add_get(counter, 1, 1) == 1
      end
    end
  end

  defmodule MFAHandler do
    @moduledoc false
    def deliver(event), do: send(:jetstream_mfa_consumer, {:mfa_event, event})
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

  defp start_jetstream(opts) do
    [
      handler: self(),
      transport: FakeTransport,
      transport_opts: [test_pid: self()],
      backoff_initial: 10,
      backoff_max: 50
    ]
    |> Keyword.merge(opts)
    |> Jetstream.start_link()
  end

  test "requires a valid handler" do
    assert {:error, :invalid_handler} = start_jetstream(handler: "not a handler")
  end

  test "connects to the subscribe endpoint of the relay" do
    {:ok, _pid} = start_jetstream(relay: "wss://jetstream.example.com")

    assert_receive {:jetstream_connected, url}
    assert url == "wss://jetstream.example.com/subscribe"
  end

  test "passes wanted collections and dids as repeated query parameters" do
    {:ok, _pid} =
      start_jetstream(
        wanted_collections: ["place.quintal.feed.prosa", "place.quintal.graph.follow"],
        wanted_dids: ["did:plc:hoyoz2vqz74upepwfqoxcooz"]
      )

    assert_receive {:jetstream_connected, url}
    assert url =~ "wantedCollections=place.quintal.feed.prosa"
    assert url =~ "wantedCollections=place.quintal.graph.follow"
    assert url =~ "wantedDids=did%3Aplc%3Ahoyoz2vqz74upepwfqoxcooz"
  end

  test "passes the cursor as a query parameter for playback" do
    {:ok, _pid} = start_jetstream(cursor: 1_725_516_133_891_108)

    assert_receive {:jetstream_connected, url}
    assert url =~ "cursor=1725516133891108"
  end

  test "delivers decoded events to a pid handler and tracks the cursor" do
    {:ok, pid} = start_jetstream([])
    assert_receive {:jetstream_connected, _url}
    assert Jetstream.cursor(pid) == nil

    send(pid, {:fake_frame, @commit})

    assert_receive {:jetstream,
                    %Event{
                      type: :commit,
                      did: "did:plc:hoyoz2vqz74upepwfqoxcooz",
                      time_us: time_us,
                      collection: "place.quintal.feed.prosa",
                      operation: :create,
                      record: %{"texto" => "quintal na janela"}
                    }}

    assert time_us == 1_725_516_133_891_108
    assert Jetstream.cursor(pid) == time_us
  end

  test "delivers events to a function handler" do
    test_pid = self()
    {:ok, pid} = start_jetstream(handler: fn event -> send(test_pid, {:fun_event, event}) end)
    assert_receive {:jetstream_connected, _url}

    send(pid, {:fake_frame, @identity})

    assert_receive {:fun_event, %Event{type: :identity, did: "did:plc:hoyoz2vqz74upepwfqoxcooz"}}
  end

  test "delivers events to a {module, function} handler" do
    Process.register(self(), :jetstream_mfa_consumer)

    {:ok, pid} = start_jetstream(handler: {MFAHandler, :deliver})
    assert_receive {:jetstream_connected, _url}

    send(pid, {:fake_frame, @commit})

    assert_receive {:mfa_event, %Event{type: :commit, operation: :create}}
  end

  test "ignores unknown messages and frames it cannot decode" do
    {:ok, pid} = start_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(pid, :some_random_message)
    send(pid, {:fake_frame, "garbage, definitely not json"})
    send(pid, {:fake_frame, ~s({"kind": "commit"})})

    refute_receive {:jetstream, _event}
    assert Process.alive?(pid)
  end

  test "reconnects after a connection failure, resuming from the last cursor" do
    {:ok, pid} = start_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(pid, {:fake_frame, @commit})
    assert_receive {:jetstream, %Event{time_us: time_us}}

    send(pid, :fake_close)

    assert_receive {:jetstream_connected, url}
    assert url =~ "cursor=#{time_us}"
    assert Process.alive?(pid)
  end

  test "reconnects after a transport error" do
    {:ok, pid} = start_jetstream([])
    assert_receive {:jetstream_connected, _url}

    send(pid, :fake_error)

    assert_receive {:jetstream_connected, _url}
    assert Process.alive?(pid)
  end

  test "retries when the initial connect fails" do
    counter = :atomics.new(1, signed: false)

    {:ok, _pid} = start_jetstream(transport_opts: [test_pid: self(), fail_once: counter])

    assert_receive :jetstream_connect_failed
    assert_receive {:jetstream_connected, _url}
  end

  test "stops when the connection drops and auto_reconnect is false" do
    Process.flag(:trap_exit, true)

    {:ok, pid} = start_jetstream(auto_reconnect: false)
    assert_receive {:jetstream_connected, _url}

    send(pid, :fake_close)

    assert_receive {:EXIT, ^pid, {:jetstream_disconnected, :closed}}
  end
end
