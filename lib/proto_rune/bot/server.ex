defmodule ProtoRune.Bot.Server do
  @moduledoc """
  The `ProtoRune.Bot.Server` module is responsible for managing bot processes in ProtoRune.
  It handles bot initialization, session management, and event/message dispatching. This
  module also integrates with the polling system to retrieve real-time notifications from
  ATProto and Bluesky services.

  The bot server can operate in two modes:
  - **Polling**: Periodically fetches notifications using the `ProtoRune.Bot.Poller` module.
  - **Firehose**: (Not yet implemented) Stream real-time events using a websocket-like connection.

  ## Features

  - **Bot Lifecycle Management**: The server manages the entire bot lifecycle, from login
    and session refresh to handling messages and events.
  - **Polling Strategy**: Supports polling for notifications at regular intervals via the
    `ProtoRune.Bot.Poller`.
  - **Session Management**: Automatically handles session creation, refresh, and expiration.
  - **Event and Message Handling**: Provides a unified interface for handling events and messages
    via `handle_message/1` and `handle_event/2`.

  ## Options

  - `:name` (required) - The name of the bot process.
  - `:lang` - A list of languages the bot supports (default: `["en"]`).
  - `:service` - The service endpoint the bot will connect to (default: `"https://bsky.social"`).
  - `:identifier` - The bot's login identifier (e.g., email or username).
  - `:password` - The bot's password for login.
  - `:polling` - Polling configuration (e.g., interval and process_from).
  - `:firehose` - Firehose configuration (not implemented yet).
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

  ## Firehose Configuration (Not Implemented)

  While not yet available, the firehose strategy will enable real-time notifications using a
  websocket connection. Firehose configuration includes:
  - `:relay_uri` - The WebSocket URI for the relay server.
  - `:auto_reconnect` - Automatically reconnect if the connection drops (default: true).
  - `:cursor` - The starting cursor for reading the stream.

  ## Functions

  - `start_link/1`: Starts the bot process with the given configuration options.
  - `handle_message/2`: Handles incoming messages for the bot.
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

  The bot can handle messages and events like this:

  ```elixir
  ProtoRune.Bot.Server.handle_message(:my_bot, "hello")
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
  """

  use GenServer

  import Peri

  alias ProtoRune.Atproto
  alias ProtoRune.Bot.Poller
  alias ProtoRune.Bsky

  require Logger

  @type polling_t :: %{
          optional(:interval) => integer,
          optional(:process_from) => NaveDateTime.t()
        }

  @type firehose_t :: %{
          optional(:relay_uri) => String.t(),
          optional(:auto_reconnect) => boolean,
          optional(:cursor) => String.t()
        }

  @type option ::
          {:name, atom}
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
    cursor: {:string, {:default, "latest"}}
  })

  @spec start_link(options_t) :: {:ok, pid} | {:error, term}
  def start_link(opts) do
    data = options_t!(opts)

    if data[:strategy] == :firehose do
      raise "Firehose strategy not implemented yet."
    end

    GenServer.start_link(__MODULE__, data, name: data[:name])
  end

  @spec handle_message(pid | atom, String.t()) :: :ok
  def handle_message(name, message) do
    GenServer.cast(name, {:handle_message, message})
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
    identifier = state[:identifier] || state[:name].get_identifier()
    password = state[:password] || state[:name].get_password()

    with {:ok, session} <-
           Atproto.Server.create_session(identifier: identifier, password: password),
         {:ok, profile} <- Bsky.Actor.get_profile(session, actor: session.did) do
      schedule_refresh_session()

      {:noreply,
       state
       |> Map.put(:did, profile[:did])
       |> Map.put(:session, Map.take(session, [:access_jwt, :refresh_jwt])),
       {:continue, :start_listener}}
    else
      err -> {:stop, err, state}
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

  @impl true
  def handle_cast({:handle_message, message}, %{name: bot} = state) do
    bot.handle_message(message)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:handle_event, event, payload}, %{name: bot} = state) do
    bot.handle_event(event, payload)
    {:noreply, state}
  end

  @impl true
  def handle_info({:handle_event, event, payload}, state) do
    handle_event(state[:name], event, payload)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh_session, state) do
    Logger.info("[#{__MODULE__}] ==> Refreshing session for bot #{state[:name]}")

    case Atproto.Server.refresh_session(state[:session]) do
      {:ok, session} ->
        send(state[:poller], {:refresh_session, session})
        schedule_refresh_session()
        {:noreply, Map.put(state, :session, Map.take(session, [:access_jwt, :refresh_jwt]))}

      err ->
        {:stop, err, state}
    end
  end

  @impl true
  def format_status({:state, state}) do
    {:state, Map.take(state, [:name, :service, :profile, :langs])}
  end

  def format_status(key), do: key

  defp schedule_refresh_session do
    Process.send_after(self(), :refresh_session, :timer.minutes(5))
  end
end
