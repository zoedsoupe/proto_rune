defmodule ProtoRune.Bot.Server do
  @moduledoc """
  The `ProtoRune.Bot.Server` module is responsible for managing bot processes in ProtoRune.
  It handles bot initialization, session management, and event/message dispatching. This
  module also integrates with the polling system to retrieve real-time notifications from
  ATProto and Bluesky services.

  The bot server can operate in two modes:
  - **Polling**: Periodically fetches notifications using the `ProtoRune.Bot.Poller` module.
  - **Firehose**: Streams real-time repo events over a WebSocket connection using the
    `ProtoRune.Bot.Firehose` module.

  ## Features

  - **Bot Lifecycle Management**: The server manages the entire bot lifecycle, from login
    and session refresh to handling messages and events.
  - **Polling Strategy**: Supports polling for notifications at regular intervals via the
    `ProtoRune.Bot.Poller`.
  - **Session Management**: Automatically handles session creation, refresh, and expiration.
  - **Event Handling**: Dispatches events to the bot's `handle_event/2` callback.

  ## Options

  - `:name` (required) - The name of the bot process.
  - `:module` - The module implementing the `ProtoRune.Bot` callbacks
    (defaults to `:name`, which covers the usual
    `use ProtoRune.Bot, name: __MODULE__` setup).
  - `:lang` - A list of languages the bot supports (default: `["en"]`).
  - `:service` - The service endpoint the bot will connect to (default: `"https://bsky.social"`).
  - `:identifier` - The bot's login identifier (e.g., email or username).
  - `:password` - The bot's password for login.
  - `:polling` - Polling configuration (e.g., interval and process_from).
  - `:firehose` - Firehose configuration (e.g., relay_uri, cursor and auto_reconnect).
  - `:strategy` - The bot's strategy for receiving notifications (`:polling` or `:firehose`).

  ## Polling Configuration

  Polling can be configured with the following options:
  - `:interval` - How often (in seconds) the bot should poll for notifications (default: 5 seconds).
  - `:process_from` - Start processing notifications from a specific timestamp (default: current time).

  Example:
  ```elixir
  ProtoRune.Bot.Server.start_link(
    name: :my_bot,
    strategy: :polling,
    service: "https://bsky.social",
    polling: %{interval: 10}
  )
  ```

  ## Firehose Configuration

  The firehose strategy streams real-time repo events using a WebSocket connection to a
  relay. Firehose configuration includes:
  - `:relay_uri` - The WebSocket URI for the relay server (default: `"wss://bsky.network"`).
  - `:auto_reconnect` - Automatically reconnect if the connection drops (default: true).
  - `:cursor` - The starting sequence number for reading the stream, used to backfill
    events missed while disconnected. Accepts an integer, a numeric string or `"latest"`
    (default: `"latest"`).

  Example:
  ```elixir
  ProtoRune.Bot.Server.start_link(
    name: :my_bot,
    strategy: :firehose,
    service: "https://bsky.social",
    firehose: %{cursor: 32_625_482_169}
  )
  ```

  ## Functions

  - `start_link/1`: Starts the bot process with the given configuration options.
  - `handle_event/3`: Handles events dispatched to the bot.
  - `format_status/1`: Formats the bot's internal state for debugging.

  ## Session Management

  The bot manages its session by authenticating with the ATProto server upon startup.
  It also refreshes the session token periodically. If the session expires or cannot be
  refreshed, the bot will stop.

  ## Example

  ```elixir
  ProtoRune.Bot.Server.start_link([
    name: :my_bot,
    strategy: :polling,
    service: "https://bsky.social",
    identifier: "my-bot-id",
    password: "super-secret-password"
  ])
  ```

  This will start a bot that uses the polling strategy to retrieve notifications from the
  Bsky service every 5 seconds.

  Events can be injected directly:

  ```elixir
  ProtoRune.Bot.Server.handle_event(:my_bot, :user_joined, %{user: "user123"})
  ```

  ## Internal State

  The server maintains a state that includes:
  - `name`: The bot's name.
  - `service`: The endpoint to connect to.
  - `session`: The session data for making authenticated requests.
  - `poller`: The PID of the polling process (if using the polling strategy).
  - `langs`: The languages the bot supports.

  ## Error Handling

  - The bot gracefully handles errors such as rate limits and API failures by retrying or
    stopping the process when necessary.
  - Errors are dispatched as events to the bot, allowing custom error handling.

  ## Telemetry

  The server emits the following `:telemetry` events (see the `ProtoRune.Bot`
  moduledoc for the full list of bot events):

  - `[:proto_rune, :bot, :event, :start]` / `[:proto_rune, :bot, :event, :stop]` /
    `[:proto_rune, :bot, :event, :exception]` - wrap each `handle_event/2` dispatch
    via `:telemetry.span/3`. Metadata includes `:bot` (the bot module) and `:event`
    (the event type); exception events also carry `:kind`, `:reason` and `:stacktrace`.
  - `[:proto_rune, :bot, :event, :dispatch]` - emitted once per dispatched event with
    measurement `%{count: 1}` and the same `:bot` / `:event` metadata, suitable for
    counting the event type distribution.
  """

  use GenServer

  import Peri

  alias ProtoRune.Bot.Firehose
  alias ProtoRune.Bot.Poller
  alias ProtoRune.Bsky
  alias ProtoRune.Session

  require Logger

  @type polling_t :: %{
          optional(:interval) => integer,
          optional(:process_from) => NaiveDateTime.t()
        }

  @type firehose_t :: %{
          optional(:relay_uri) => String.t(),
          optional(:auto_reconnect) => boolean,
          optional(:cursor) => String.t() | non_neg_integer
        }

  @type option ::
          {:name, atom}
          | {:module, atom}
          | {:lang, list(String.t())}
          | {:service, String.t()}
          | {:identifier, String.t() | nil}
          | {:password, String.t() | nil}
          | {:polling, polling_t | nil}
          | {:firehose, firehose_t | nil}
          | {:strategy, :polling | :firehose}

  @type kwargs :: nonempty_list(option)

  @type mapargs :: %{
          required(:name) => atom,
          required(:strategy) => :polling | :firehose,
          required(:service) => String.t(),
          optional(:langs) => list(String.t()),
          optional(:identifier) => String.t(),
          optional(:password) => String.t(),
          optional(:polling) => polling_t,
          optional(:firehose) => firehose_t
        }

  @type options_t :: kwargs | mapargs

  defschema(:options_t, %{
    name: {:required, :atom},
    module: :atom,
    langs: {{:list, :string}, {:default, ["en"]}},
    service: {:string, {:default, "https://bsky.social"}},
    identifier: :string,
    password: :string,
    strategy: {{:enum, [:polling, :firehose]}, {:default, :polling}},
    polling: {:cond, &(&1.strategy == :polling), get_schema(:polling_t), nil},
    firehose: {:cond, &(&1.strategy == :firehose), get_schema(:firehose_t), nil}
  })

  defschema(:polling_t, %{
    interval: {:integer, {:default, 5}},
    process_from: {:naive_datetime, {:default, &NaiveDateTime.utc_now/0}}
  })

  defschema(:firehose_t, %{
    relay_uri: {:string, {:default, "wss://bsky.network"}},
    auto_reconnect: {:boolean, {:default, true}},
    cursor: {{:either, {:string, :integer}}, {:default, "latest"}}
  })

  @spec start_link(options_t) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    data = options_t!(opts)

    GenServer.start_link(__MODULE__, data, name: data[:name])
  end

  @spec handle_event(pid | atom, atom, map) :: :ok
  def handle_event(name, event, payload \\ %{}) do
    GenServer.cast(name, {:handle_event, event, payload})
  end

  @impl true
  def init(data) do
    Logger.info("[#{__MODULE__}] ==> Starting bot #{data[:name]} at #{data[:service]}")
    {:ok, data, {:continue, :fetch_bot_profile}}
  end

  @impl true
  def handle_continue(:fetch_bot_profile, state) do
    bot = bot_module(state)
    identifier = state[:identifier] || bot.get_identifier()
    password = state[:password] || bot.get_password()

    case ProtoRune.login(identifier, password, service: state[:service]) do
      {:ok, session} ->
        case Bsky.Actor.get_profile(session, actor: session.did) do
          {:ok, profile} ->
            schedule_refresh_session()

            {:noreply,
             state
             |> Map.put(:did, profile[:did])
             |> Map.put(:session, session), {:continue, :start_listener}}

          err ->
            {:stop, err, state}
        end

      err ->
        {:stop, err, state}
    end
  end

  def handle_continue(:start_listener, %{strategy: :polling} = state) do
    interval = state[:polling][:interval]
    process_from = state[:polling][:process_from]
    name = :"#{state[:name]}_poller"

    {:ok, pid} =
      Poller.start_link(
        server_pid: self(),
        name: name,
        interval: interval,
        process_from: process_from,
        session: state[:session]
      )

    {:noreply, Map.put(state, :poller, pid)}
  end

  def handle_continue(:start_listener, %{strategy: :firehose} = state) do
    name = :"#{state[:name]}_firehose"

    {:ok, pid} =
      Firehose.start_link(
        server_pid: self(),
        name: name,
        relay: state[:firehose][:relay_uri],
        cursor: state[:firehose][:cursor],
        auto_reconnect: state[:firehose][:auto_reconnect]
      )

    {:noreply, Map.put(state, :firehose, pid)}
  end

  @impl true
  def handle_cast({:handle_event, event, payload}, state) do
    dispatch_event(state, event, payload)
    {:noreply, state}
  end

  @impl true
  def handle_info({:handle_event, event, payload}, state) do
    dispatch_event(state, event, payload)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh_session, state) do
    Logger.info("[#{__MODULE__}] ==> Refreshing session for bot #{state[:name]}")

    case Session.refresh(state[:session]) do
      {:ok, session} ->
        if state[:poller], do: send(state[:poller], {:refresh_session, session})
        schedule_refresh_session()
        {:noreply, Map.put(state, :session, session)}

      err ->
        {:stop, err, state}
    end
  end

  @impl true
  def format_status({:state, state}) do
    {:state, Map.take(state, [:name, :service, :profile, :langs])}
  end

  def format_status(key), do: key

  defp dispatch_event(state, event, payload) do
    bot = bot_module(state)
    metadata = %{bot: bot, event: event}

    :telemetry.execute([:proto_rune, :bot, :event, :dispatch], %{count: 1}, metadata)

    :telemetry.span([:proto_rune, :bot, :event], metadata, fn ->
      {bot.handle_event(event, payload), metadata}
    end)
  end

  # The `:module` option names the callback module explicitly; when absent
  # the process `:name` doubles as the callback module (the historical
  # `use ProtoRune.Bot, name: __MODULE__` setup).
  defp bot_module(state), do: state[:module] || state[:name]

  defp schedule_refresh_session do
    Process.send_after(self(), :refresh_session, to_timeout(minute: 5))
  end
end
