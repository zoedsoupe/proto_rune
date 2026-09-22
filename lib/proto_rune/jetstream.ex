defmodule ProtoRune.Jetstream do
  @moduledoc """
  Consumer for the AT Protocol Jetstream, the filtered JSON re-encode of
  the repo firehose.

  Where `ProtoRune.Firehose` delivers every commit on the network and
  decodes every CAR block locally, Jetstream applies `wantedCollections`
  and `wantedDids` filters server-side and ships plain JSON text frames:
  a consumer that only cares about a handful of collections receives (and
  pays to decode) only those events. Add it to your supervision tree:

      children = [
        {ProtoRune.Jetstream,
         handler: MyConsumer, wanted_collections: ["place.quintal.feed.prosa"]}
      ]

  or start it directly with `start_link/1`.

  ## Handlers

  The required `:handler` option tells the consumer where events go:

    * a pid, which receives `{:jetstream, %ProtoRune.Jetstream.Event{}}` messages
    * a one-arity function, called with the event
    * a `{module, function}` tuple, called as `function.(event)`

  ## Filtering and cursors

    * `:wanted_collections` - AT-URI collections to receive commit events
      for (repeatable server-side filter). Identity and account events
      are not collection-scoped and always flow through.
    * `:wanted_dids` - restrict events to these repository DIDs.
    * `:cursor` - a `time_us` timestamp (microseconds) to resume from.
      Jetstream keeps a rolling playback window; resuming may re-deliver
      a handful of events around the cursor, so consumers must stay
      idempotent. When the connection drops, the consumer reconnects
      resuming from the last delivered `time_us`. `cursor/1` returns the
      current value, e.g. to persist it for a later restart.

  ## Remaining options

    * `:relay` - the Jetstream instance base URL
      (default: `"wss://jetstream2.us-east.bsky.network"`).
    * `:auto_reconnect` - reconnect automatically on connection loss
      (default: `true`). When `false`, the process stops with reason
      `{:jetstream_disconnected, reason}` instead.
    * `:backoff_initial` / `:backoff_max` - reconnect backoff bounds in
      milliseconds (default: `1_000` / `30_000`). The delay doubles after
      each failed attempt and resets once connected.
    * `:transport` - the `ProtoRune.Firehose.Transport` implementation to
      use (default: `ProtoRune.Firehose.Transport.Gun`). Jetstream speaks
      the same WebSocket transport as the firehose, only with text frames.
    * `:transport_opts` - options passed to the transport.
    * `:name` - registers the process under the given name.
  """

  import Peri

  alias ProtoRune.Jetstream.Event
  alias ProtoRune.StreamClient

  @default_relay "wss://jetstream2.us-east.bsky.network"
  @subscribe_path "/subscribe"

  @typedoc "Where decoded events are delivered to."
  @type handler :: pid | (Event.t() -> term) | {module, atom}

  defschema(:options_t, %{
    name: :atom,
    relay: {:string, {:default, @default_relay}},
    cursor: :integer,
    wanted_collections: {{:list, :string}, {:default, []}},
    wanted_dids: {{:list, :string}, {:default, []}},
    handler: {:required, :any},
    auto_reconnect: {:boolean, {:default, true}},
    backoff_initial: {:integer, {:default, 1_000}},
    backoff_max: {:integer, {:default, 30_000}},
    transport: {:atom, {:default, ProtoRune.Firehose.Transport.Gun}},
    transport_opts: {:any, {:default, []}}
  })

  @doc """
  Starts a Jetstream consumer process.

  See the module documentation for the available options.
  """
  @spec start_link(keyword | map) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    data = options_t!(opts)

    case validate_handler(data[:handler]) do
      :ok -> StreamClient.start_link(config(data), start_opts(data))
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the `time_us` of the last delivered event, or `nil` when no
  event has been delivered yet.
  """
  @spec cursor(GenServer.server()) :: non_neg_integer | nil
  def cursor(server), do: StreamClient.cursor(server)

  defp config(data) do
    relay = String.trim_trailing(data[:relay], "/") <> @subscribe_path

    filters =
      Enum.map(data[:wanted_collections], &{"wantedCollections", &1}) ++
        Enum.map(data[:wanted_dids], &{"wantedDids", &1})

    %{
      handler: data[:handler],
      cursor: data[:cursor],
      auto_reconnect: data[:auto_reconnect],
      backoff_initial: data[:backoff_initial],
      backoff_max: data[:backoff_max],
      transport: data[:transport],
      transport_opts: data[:transport_opts],
      tag: :jetstream,
      frame: :text,
      label: "jetstream at #{data[:relay]}",
      stop_reason: :jetstream_disconnected,
      url_fun: fn cursor ->
        params = if cursor, do: filters ++ [{"cursor", Integer.to_string(cursor)}], else: filters
        if params == [], do: relay, else: relay <> "?" <> URI.encode_query(params)
      end,
      decode_fun: fn frame ->
        with {:ok, message} <- JSON.decode(frame),
             {:ok, %Event{} = event} <- Event.from_message(message) do
          {:ok, event, event.time_us}
        end
      end
    }
  end

  defp start_opts(data) do
    case Map.get(data, :name) do
      nil -> []
      name -> [name: name]
    end
  end

  defp validate_handler(handler) when is_pid(handler), do: :ok
  defp validate_handler(handler) when is_function(handler, 1), do: :ok
  defp validate_handler({module, function}) when is_atom(module) and is_atom(function), do: :ok
  defp validate_handler(_other), do: {:error, :invalid_handler}
end
