defmodule ProtoRune.Bot.FirehoseTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Bot.Firehose

  @fixtures_dir Path.expand("../../fixtures/firehose", __DIR__)

  defmodule FakeTransport do
    @moduledoc false

    @behaviour ProtoRune.Firehose.Transport

    @impl true
    def connect(url, opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      send(test_pid, {:firehose_connected, url})
      {:ok, %{test_pid: test_pid}}
    end

    @impl true
    def stream(state, {:fake_frame, data}), do: {:ok, state, [{:binary, data}]}
    def stream(state, :fake_close), do: {:ok, state, [:closed]}
    def stream(_state, _message), do: :unknown

    @impl true
    def close(_state), do: :ok
  end

  defp start_bot_firehose(opts) do
    [
      name: :"bot_firehose_#{System.unique_integer([:positive])}",
      server_pid: self(),
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

  test "connects to the subscribeRepos endpoint of the relay" do
    {:ok, _pid} = start_bot_firehose(relay: "wss://relay.example.com")

    assert_receive {:firehose_connected, url}
    assert url == "wss://relay.example.com/xrpc/com.atproto.sync.subscribeRepos"
  end

  test "passes an integer cursor as a query parameter for backfill" do
    {:ok, _pid} = start_bot_firehose(cursor: 32_625_482_169)

    assert_receive {:firehose_connected, url}
    assert url =~ "cursor=32625482169"
  end

  test "accepts a numeric string as cursor for backfill" do
    {:ok, _pid} = start_bot_firehose(cursor: "32625482169")

    assert_receive {:firehose_connected, url}
    assert url =~ "cursor=32625482169"
  end

  test "starts from live events when the cursor is \"latest\"" do
    {:ok, _pid} = start_bot_firehose(cursor: "latest")

    assert_receive {:firehose_connected, url}
    refute url =~ "cursor="
  end

  test "dispatches a commit event per operation to the bot server" do
    {:ok, pid} = start_bot_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_00.bin"))

    assert_receive {:handle_event, :commit, payload}
    assert payload.repo == "did:plc:4vdi2b4k2klzdke344ag2njy"
    assert payload.seq == 32_625_482_169
    assert payload.action == :create
    assert payload.path =~ "app.bsky.feed.post/"
    assert payload.record["$type"] == "app.bsky.feed.post"
    assert is_binary(payload.record["text"])
  end

  test "dispatches delete operations without a record" do
    {:ok, pid} = start_bot_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_delete.bin"))

    assert_receive {:handle_event, :commit, payload}
    assert payload.action == :delete
    assert payload.path == "app.bsky.graph.follow/3lnm6stbtwi2i"
    assert payload.cid == nil
    assert payload.record == nil
  end

  test "dispatches non-commit events with the raw payload" do
    {:ok, pid} = start_bot_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_identity.bin"))

    assert_receive {:handle_event, :identity, payload}
    assert payload.repo == "did:plc:hoyoz2vqz74upepwfqoxcooz"
    assert payload.seq == 32_625_561_603
    assert payload.time == "2026-08-10T19:24:04.480Z"
  end

  test "tracks the sequence number of the last delivered event" do
    {:ok, pid} = start_bot_firehose([])
    assert_receive {:firehose_connected, _url}
    assert Firehose.cursor(pid) == nil

    send(pid, frame("frame_00.bin"))

    assert_receive {:handle_event, :commit, %{seq: seq}}
    assert Firehose.cursor(pid) == seq
  end

  test "reconnects after a connection failure, resuming from the last cursor" do
    {:ok, pid} = start_bot_firehose([])
    assert_receive {:firehose_connected, _url}

    send(pid, frame("frame_00.bin"))
    assert_receive {:handle_event, :commit, %{seq: seq}}

    send(pid, :fake_close)

    assert_receive {:firehose_connected, url}
    assert url =~ "cursor=#{seq}"
    assert Process.alive?(pid)
  end
end
