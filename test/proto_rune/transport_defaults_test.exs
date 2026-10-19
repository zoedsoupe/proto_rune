defmodule ProtoRune.TransportDefaultsTest do
  @moduledoc """
  Pins the transport-swap defaults: `Transport.Mint` is the default
  WebSocket transport and both streams are supervision-tree entry points
  (child_spec/1).
  """

  use ExUnit.Case, async: true

  alias ProtoRune.Firehose.Transport.Mint

  defmodule SpecFakeTransport do
    @moduledoc false
    @behaviour ProtoRune.Firehose.Transport

    @impl true
    def connect(_url, opts) do
      send(Keyword.fetch!(opts, :test_pid), :connected)
      {:ok, %{}}
    end

    @impl true
    def stream(_state, _message), do: :unknown

    @impl true
    def close(_state), do: :ok
  end

  describe "default transport" do
    test "the firehose defaults to Transport.Mint" do
      opts = ProtoRune.Firehose.options_t!(handler: self())
      assert opts.transport == Mint
    end

    test "the jetstream defaults to Transport.Mint" do
      opts = ProtoRune.Jetstream.options_t!(handler: self())
      assert opts.transport == Mint
    end
  end

  describe "child_spec/1" do
    test "the firehose is a supervision-tree entry point" do
      opts = [handler: self()]

      assert %{id: ProtoRune.Firehose, start: {ProtoRune.Firehose, :start_link, [^opts]}} =
               ProtoRune.Firehose.child_spec(opts)
    end

    test "the jetstream is a supervision-tree entry point" do
      opts = [handler: self()]

      assert %{id: ProtoRune.Jetstream, start: {ProtoRune.Jetstream, :start_link, [^opts]}} =
               ProtoRune.Jetstream.child_spec(opts)
    end

    test "the specs actually start under a supervisor" do
      transport_opts = [test_pid: self()]
      handler = self()

      children = [
        {ProtoRune.Firehose, handler: handler, transport: SpecFakeTransport, transport_opts: transport_opts},
        {ProtoRune.Jetstream, handler: handler, transport: SpecFakeTransport, transport_opts: transport_opts}
      ]

      assert {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
      assert_receive :connected
      assert_receive :connected
      assert Process.alive?(sup)
    end
  end
end
