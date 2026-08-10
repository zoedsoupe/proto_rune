defmodule ProtoRune.FirehoseTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Firehose
  alias ProtoRune.Firehose.Event

  @fixtures_dir Path.expand("../fixtures/firehose", __DIR__)

  defmodule FakeTransport do
    @moduledoc false

    @behaviour ProtoRune.Firehose.Transport

    @impl true
    def connect(url, opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)

      if fail_connect?(opts) do
        send(test_pid, :firehose_connect_failed)
        {:error, :econnrefused}
      else
        send(test_pid, {:firehose_connected, url})
        {:ok, %{test_pid: test_pid}}
      end
    end

    @impl true
    def stream(state, {:fake_frame, data}), do: {:ok, state, [{:binary, data}]}
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
    def deliver(event), do: send(:firehose_mfa_consumer, {:mfa_event, event})
  end

  defp start_firehose(opts) do
    [
      handler: self(),
      transport: FakeTransport,
      transport_opts: [test_pid: self()],
      backoff_initial: 10,
      backoff_max: 50
    ]
    |> Keyword.merge(opts)
    |> Firehose.start_link()
  end

  defp frame(name) do
    {:fake_frame, @fixtures_dir |> Path.join(name) |> File.read!()}
  end

  test "requires a valid handler" do
    assert {:error, :invalid_handler} = start_firehose(handler: "not a handler")
  end

  test "connects to the subscribeRepos endpoint of the relay" do
    {:ok, _pid} = start_firehose(relay: "wss://relay.example.com")

    assert_receive {:firehose_connected, url}
    assert url == "wss://relay.example.com/xrpc/com.atproto.sync.subscribeRepos"
  end

  test "passes the cursor as a query parameter for backfill" do
    {:ok, _pid} = start_firehose(cursor: 32_625_482_169)

    assert_receive {:firehose_connected, url}
    assert url =~ "cursor=32625482169"
  end

  test "delivers decoded events to a pid handler and tracks the cursor" do
    {:ok, pid} = start_firehose([])
    assert_receive {:firehose_connected, _url}
    assert Firehose.cursor(pid) == nil

    send(pid, frame("frame_00.bin"))

    assert_receive {:firehose, %Event{type: :commit, seq: seq}}
    assert seq == 32_625_482_169
    assert Firehose.cursor(pid) == seq
  end

  test "delivers events to a function handler" do
    test_pid = self()
    {:ok, pid} = start_firehose(handler: fn event -> send(test_pid, {:fun_event, event}) end)
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_identity.bin"))

    assert_receive {:fun_event, %Event{type: :identity, repo: "did:plc:hoyoz2vqz74upepwfqoxcooz"}}
  end

  test "delivers events to a {module, function} handler" do
    Process.register(self(), :firehose_mfa_consumer)

    {:ok, pid} = start_firehose(handler: {MFAHandler, :deliver})
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_delete.bin"))

    assert_receive {:mfa_event, %Event{type: :commit, ops: [%{action: :delete}]}}
  end

  test "ignores unknown messages and transport frames it cannot decode" do
    {:ok, pid} = start_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, :some_random_message)
    send(pid, {:fake_frame, "garbage, definitely not a cbor frame payload"})

    refute_receive {:firehose, _event}
    assert Process.alive?(pid)
  end

  test "reconnects after a connection failure, resuming from the last cursor" do
    {:ok, pid} = start_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_00.bin"))
    assert_receive {:firehose, %Event{seq: seq}}

    send(pid, :fake_close)

    assert_receive {:firehose_connected, url}
    assert url =~ "cursor=#{seq}"
    assert Process.alive?(pid)
  end

  test "reconnects after a transport error" do
    {:ok, pid} = start_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, :fake_error)

    assert_receive {:firehose_connected, _url}
    assert Process.alive?(pid)
  end

  test "retries when the initial connect fails" do
    counter = :atomics.new(1, signed: false)

    {:ok, _pid} = start_firehose(transport_opts: [test_pid: self(), fail_once: counter])

    assert_receive :firehose_connect_failed
    assert_receive {:firehose_connected, _url}
  end

  test "stops when the connection drops and auto_reconnect is false" do
    Process.flag(:trap_exit, true)

    {:ok, pid} = start_firehose(auto_reconnect: false)
    assert_receive {:firehose_connected, _url}

    send(pid, :fake_close)

    assert_receive {:EXIT, ^pid, {:firehose_disconnected, :closed}}
  end
end
