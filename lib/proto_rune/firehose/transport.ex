defmodule ProtoRune.Firehose.Transport do
  @moduledoc """
  Behaviour for the WebSocket transport used by `ProtoRune.Firehose`.

  A transport owns the underlying connection and translates the BEAM
  messages it receives into firehose frames. The default implementation is
  `ProtoRune.Firehose.Transport.Gun`; a different implementation can be
  injected through the `:transport` and `:transport_opts` options of
  `ProtoRune.Firehose.start_link/1`, which is how the connection lifecycle
  is exercised in tests.
  """

  @typedoc "Opaque transport connection state."
  @type conn :: term

  @typedoc """
  A decoded WebSocket frame: a binary or text payload, or a close signal.

  The CBOR firehose (`ProtoRune.Firehose`) uses binary frames; Jetstream
  (`ProtoRune.Jetstream`) uses text frames carrying JSON.
  """
  @type frame :: {:binary, binary} | {:text, binary} | :closed

  @doc """
  Opens a WebSocket connection to the given `ws(s)://` URL.

  The calling process becomes the connection owner and receives the
  socket-related messages that `stream/2` understands.
  """
  @callback connect(url :: String.t(), opts :: keyword) :: {:ok, conn} | {:error, term}

  @doc """
  Processes a message received by the connection owner.

  Returns `:unknown` when the message does not belong to the transport,
  `{:ok, conn, frames}` with the decoded frames, or `{:error, conn, reason}`
  when the connection failed.
  """
  @callback stream(conn, message :: term) :: {:ok, conn, [frame]} | :unknown | {:error, conn, term}

  @doc """
  Closes the connection.
  """
  @callback close(conn) :: :ok
end
