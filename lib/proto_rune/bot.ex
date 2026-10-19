defmodule ProtoRune.Bot do
  @moduledoc """
  The `ProtoRune.Bot` module provides the foundational behavior and macros for building bots
  in the ProtoRune ecosystem. It defines the basic structure for bots and ensures that every bot
  adheres to a consistent interface, with customizable event handling, identifier, and password
  retrieval.

  The bot system integrates with the `ProtoRune.Bot.Server` to manage bot lifecycles, handle
  events, and manage sessions. Bots can use different strategies for receiving notifications,
  such as polling, firehose, or jetstream.

  ## Usage

  To create a bot using `ProtoRune.Bot`, you need to define your bot module with the required
  callbacks: `get_identifier/0`, `get_password/0`, and `handle_event/2`.

  Here is an example bot implementation:

  ```elixir
  defmodule Walle do
    use ProtoRune.Bot,
      name: __MODULE__,
      strategy: :polling

    require Logger

    @impl true
    def get_identifier, do: System.get_env("IDENTIFIER")

    @impl true
    def get_password, do: System.get_env("PASSWORD")

    @impl true
    def handle_event(event, payload) do
      Logger.info("Event: \#{event} with URI: \#{inspect(payload[:uri])}")
    end
  end
  ```

  In this example, `Walle` is a bot that uses the polling strategy to fetch notifications.
  It retrieves its identifier and password from environment variables and logs any events it receives.

  ## Polling Strategy Events

  When using the polling strategy, the bot can receive various types of events triggered by
  notifications from the Bluesky or ATProto services. Each event type corresponds to a specific
  user action, and a payload containing relevant data is provided. Below is a list of possible
  events and their associated payloads:

  ### Event Types and Payloads

  - **`:reply`**, **`:quote`**, **`:mention`**
    - Triggered when someone replies to, quotes or mentions the bot.
    - **Payload**: the post thread view returned by
      `ProtoRune.Bsky.Feed.get_post_thread/2`, so the triggering post is
      reachable at `payload.thread.post` (for example
      `payload.thread.post.author.handle`).

  - **`:like`**
    - Triggered when someone likes a post by the bot.
    - **Payload**:
      - `:uri` - The URI of the like notification.
      - `:user` - The user who liked the post.
      - `:subject` - The thread view of the liked post.

    Example payload:
    ```elixir
    %{uri: "at://did:plc:1234", user: %{handle: "user.bsky.social"}, subject: %{thread: %{post: %{}}}}
    ```

  - **`:repost`**
    - Triggered when someone reposts content from the bot.
    - **Payload**:
      - `:uri` - The URI of the repost notification.
      - `:user` - The user who reposted the content.
      - `:post` - The thread view of the reposted post.

  - **`:follow`**
    - Triggered when someone follows the bot.
    - **Payload**:
      - `:uri` - The URI of the follow notification.
      - `:user` - The user who followed the bot.

    Example payload:
    ```elixir
    %{uri: "at://did:plc:9876", user: %{handle: "user.bsky.social"}}
    ```

  - **`:error`**
    - Triggered when there is an error while processing an event (e.g., failed to fetch a post).
    - **Payload**:
      - `:reason` - The error, usually a `ProtoRune.XRPC.Error` struct.

    Example payload:
    ```elixir
    %{reason: %ProtoRune.XRPC.Error{reason: :rate_limited, retry_after: "30"}}
    ```

  ## Callbacks

  The following callbacks must be implemented by any bot module that uses `ProtoRune.Bot`:

  - `get_identifier/0`: Retrieves the bot's identifier (e.g., username or email). This is used
    for logging into the service.

  - `get_password/0`: Retrieves the bot's password. This is used alongside the identifier
    to authenticate the bot.

  The following callbacks are optional (defaults do nothing):

  - `handle_event/2`: Handles events that are dispatched to the bot. These events can include
    mentions, replies, likes, and other interactions that the bot should process.
  - `handle_event/3`: Same as `handle_event/2`, but also receives the bot's current session,
    for handlers that need to call the API. Prefer it over reaching for the session through
    global state.
  - `handle_event/4`: Same as `handle_event/3`, but also receives the bot's current state as
    the fourth argument and treats the return value as the new state. This is the stateful
    variant for bots that track data across events; it takes precedence over the other two
    arities when defined.
  - `init_state/0`: Returns the bot's initial state. Called once by the bot server at boot;
    a bot that wants to recover persisted data loads it here instead of returning a fresh
    value. Bots without it start with `nil`.
  - `persist_state/1`: Called by the bot server on each persistence tick so the bot saves
    its state wherever it wants (disk, ETS, a database). `{:error, reason}` returns are
    logged and never fatal.

  The `handle_event/2` function receives:
  - `event`: An atom that represents the type of event (e.g., `:mention`, `:like`, `:reply`).
  - `payload`: A map containing the data related to the event, such as the URI of the post or the user who triggered the event.

  ## State Persistence

  Stateful bots combine the state callbacks with the `:persist_interval` option (in
  seconds): the server seeds the state from `init_state/0` at boot, threads it through every
  `handle_event/4` dispatch, and calls `persist_state/1` on each tick so the bot can save it
  wherever it wants:

  ```elixir
  defmodule Counter do
    use ProtoRune.Bot,
      name: __MODULE__,
      strategy: :polling,
      persist_interval: 30

    def init_state, do: 0

    def handle_event(:mention, _payload, _session, count), do: count + 1

    def persist_state(count) do
      File.write!("counter.dat", Integer.to_string(count))
    end
  end
  ```

  On the next boot, `init_state/0` reads the file back and the count resumes. Persistence
  is opt-in: without `:persist_interval` the server never calls `persist_state/1`, and
  without `handle_event/4` the state stays at its initial value.

  ## Bot Lifecycle

  The bot is started using `start_link/0`, which initializes the bot server with the provided options.
  The server handles the bot's session and dispatches messages or events to the bot's defined handlers.

  For instance, starting the bot would look like this:

  ```elixir
  Walle.start_link()
  ```

  The generated module also implements `child_spec/1` (the configured `:name`
  is the child id), so bots fit directly into a supervision tree:

  ```elixir
  children = [Walle]
  ```

  ## Customizing the Bot

  - **Authentication**: Bots must implement `get_identifier/0` and `get_password/0` to provide authentication details.
  - **Event Handling**: The `handle_event/2` function allows bots to react to different types of events such as mentions, replies, and likes.

  ## Example Workflow

  When the bot receives a notification (for example, a new mention), the following happens:

  1. The bot's `handle_event/2` callback is called with the event type and payload.
  2. The bot processes the event and can take actions such as replying, liking a post, or logging information.

  ## Notes

  - The polling strategy fetches the bot's notifications periodically; the firehose
    strategy streams real-time repo events (see `ProtoRune.Bot.Firehose` for the events it
    dispatches and its backpressure caveat); the jetstream strategy streams the same
    events, server-side filtered, through `ProtoRune.Bot.Jetstream`.
  - Bots should be designed to handle events and messages in a non-blocking manner for efficient performance.

  ## Telemetry

  The bot framework emits `:telemetry` events under the `[:proto_rune, :bot]`
  namespace for observability:

  - `[:proto_rune, :bot, :event, :start]` / `[:proto_rune, :bot, :event, :stop]` /
    `[:proto_rune, :bot, :event, :exception]` - wrap each `handle_event/2` dispatch
    via `:telemetry.span/3`. Measurements: `:system_time` on start, `:duration` on
    stop and exception. Metadata: `:bot` (the bot module) and `:event` (the event
    type); exception events also carry `:kind`, `:reason` and `:stacktrace`.

  - `[:proto_rune, :bot, :event, :dispatch]` - emitted once per dispatched event
    with measurement `%{count: 1}` and metadata `:bot` and `:event`. Count it
    grouped by the `:event` metadata to build the event type distribution.

  - `[:proto_rune, :bot, :poll, :start]` / `[:proto_rune, :bot, :poll, :stop]` /
    `[:proto_rune, :bot, :poll, :exception]` - wrap each polling cycle via
    `:telemetry.span/3`. Measurements follow the same span conventions.
    Metadata: `:poller` (the poller process name).

  - `[:proto_rune, :bot, :rate_limited]` - emitted when a poll hits an API rate
    limit, with measurement `%{count: 1}` and metadata `:poller`, `:retry_in`
    (milliseconds until the next poll) and `:attempt` (consecutive rate-limited
    attempts).
  """

  alias ProtoRune.Bot.Server
  alias ProtoRune.Session

  @callback get_identifier :: String.t()
  @callback get_password :: String.t()

  @callback handle_event(event :: atom(), data :: map()) :: term

  @doc """
  Handles an event with the bot's current session.

  Optional: prefer this over `handle_event/2` when the handler needs to call
  the API (replying, following back, and so on). The server passes the
  session it authenticated with, so handlers do not need to reach for the
  session through global state.
  """
  @callback handle_event(event :: atom(), data :: map(), session :: Session.t()) :: term

  @doc """
  Handles an event with the bot's current session and state, returning the new state.

  Optional stateful variant: the server passes the bot's current state (seeded by
  `init_state/0`) as the fourth argument and stores the return value as the new
  state. Takes precedence over `handle_event/3` and `handle_event/2` when defined.
  """
  @callback handle_event(event :: atom(), data :: map(), session :: Session.t(), state :: term) ::
              term

  @doc """
  Returns the bot's initial state.

  Optional: called once by the bot server at boot. A bot that wants to recover
  its persisted data loads it here instead of returning a fresh value. Bots
  without this callback start with `nil`.
  """
  @callback init_state :: term

  @doc """
  Persists the bot's current state.

  Optional: called by the bot server on each persistence tick (see the
  `:persist_interval` option) with the current bot state. Save it wherever the
  bot wants (disk, ETS, a database). `{:error, reason}` returns are logged and
  never crash the server.
  """
  @callback persist_state(state :: term) :: :ok | {:error, term}

  @optional_callbacks handle_event: 3, handle_event: 4, init_state: 0, persist_state: 1

  @spec __using__(Server.options_t()) :: Macro.t()
  defmacro __using__(opts) do
    quote do
      @behaviour ProtoRune.Bot

      def start_link do
        Server.start_link(unquote(opts))
      end

      # The child id is the bot name, so several bots share a supervision tree.
      def child_spec(_opts) do
        %{id: unquote(opts)[:name] || __MODULE__, start: {__MODULE__, :start_link, []}}
      end

      # Default implementation for the optional event callback
      @impl ProtoRune.Bot
      def handle_event(_, _), do: :ok

      @impl ProtoRune.Bot
      def handle_event(event, payload, _session), do: handle_event(event, payload)

      defoverridable handle_event: 2, handle_event: 3
    end
  end
end
