defmodule ProtoRune.Firehose.Transport.Gun do
  @moduledoc """
  `ProtoRune.Firehose.Transport` implementation backed by `:gun`.

  Connects with TLS enabled by default for `wss://` URLs. Gun answers pings
  and reassembles fragmented WebSocket messages by itself, so this module
  only translates `:gun` messages into transport frames.
  """

  @behaviour ProtoRune.Firehose.Transport

  defstruct [:pid, :stream_ref, :monitor_ref]

  @impl true
  def connect(url, opts) do
    uri = URI.parse(url)
    timeout = Keyword.get(opts, :timeout, 5_000)
    secure? = uri.scheme != "ws"
    port = uri.port || if(secure?, do: 443, else: 80)
    path = if uri.query, do: "#{uri.path}?#{uri.query}", else: uri.path

    gun_opts = %{retry: 0, connect_timeout: timeout}
    gun_opts = if secure?, do: Map.put(gun_opts, :transport, :tls), else: gun_opts

    with {:ok, pid} <- :gun.open(String.to_charlist(uri.host), port, gun_opts),
         {:ok, _protocol} <- :gun.await_up(pid, timeout),
         monitor_ref = Process.monitor(pid),
         stream_ref = :gun.ws_upgrade(pid, path),
         {:ok, ^stream_ref} <- await_upgrade(pid, stream_ref, monitor_ref, timeout) do
      {:ok, %__MODULE__{pid: pid, stream_ref: stream_ref, monitor_ref: monitor_ref}}
    end
  end

  defp await_upgrade(pid, stream_ref, monitor_ref, timeout) do
    receive do
      {:gun_upgrade, ^pid, ^stream_ref, ["websocket"], _headers} ->
        {:ok, stream_ref}

      {:gun_response, ^pid, ^stream_ref, _fin, status, _headers} ->
        {:error, {:ws_upgrade_failed, status}}

      {:gun_error, ^pid, ^stream_ref, reason} ->
        {:error, reason}

      {:gun_error, ^pid, reason} ->
        {:error, reason}

      {:DOWN, ^monitor_ref, :process, ^pid, reason} ->
        {:error, reason}
    after
      timeout -> {:error, :timeout}
    end
  end

  @impl true
  def stream(%__MODULE__{pid: pid, stream_ref: stream_ref} = conn, message) do
    case message do
      {:gun_ws, ^pid, ^stream_ref, {:binary, data}} ->
        {:ok, conn, [{:binary, data}]}

      {:gun_ws, ^pid, ^stream_ref, :close} ->
        {:ok, conn, [:closed]}

      {:gun_ws, ^pid, ^stream_ref, {:close, _code, _reason}} ->
        {:ok, conn, [:closed]}

      {:gun_ws, ^pid, ^stream_ref, {:text, _data}} ->
        {:ok, conn, []}

      {:gun_down, ^pid, :ws, _reason, _killed, _unprocessed} ->
        {:ok, conn, [:closed]}

      {:DOWN, ref, :process, ^pid, reason} when ref == conn.monitor_ref ->
        {:error, conn, reason}

      _other ->
        :unknown
    end
  end

  @impl true
  def close(%__MODULE__{pid: pid, monitor_ref: monitor_ref}) do
    Process.demonitor(monitor_ref, [:flush])
    :gun.close(pid)
    :ok
  end
end
