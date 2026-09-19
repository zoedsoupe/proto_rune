defmodule ProtoRune.Bot do
  @moduledoc """
  The `ProtoRune.Bot` module provides the foundational behavior and macros for building bots
  in the ProtoRune ecosystem. It defines the basic structure for bots and ensures that every bot
  adheres to a consistent interface, with customizable event handling, identifier, and password
  retrieval.

  The bot system integrates with the `ProtoRune.Bot.Server` to manage bot lifecycles, handle
  events, and manage sessions. Bots can use different strategies for receiving notifications,
  such as polling or firehose.

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

  The following callback is optional (the default does nothing):

  - `handle_event/2`: Handles events that are dispatched to the bot. These events can include
    mentions, replies, likes, and other interactions that the bot should process.

  The `handle_event/2` function receives:
  - `event`: An atom that represents the type of event (e.g., `:mention`, `:like`, `:reply`).
  - `payload`: A map containing the data related to the event, such as the URI of the post or the user who triggered the event.

  ## Bot Lifecycle

  The bot is started using `start_link/0`, which initializes the bot server with the provided options.
  The server handles the bot's session and dispatches messages or events to the bot's defined handlers.

  For instance, starting the bot would look like this:

  ```elixir
  Walle.start_link()
  ```

  ## Customizing the Bot

  - **Authentication**: Bots must implement `get_identifier/0` and `get_password/0` to provide authentication details.
  - **Event Handling**: The `handle_event/2` function allows bots to react to different types of events such as mentions, replies, and likes.

  ## Example Workflow

  When the bot receives a notification (for example, a new mention), the following happens:

  1. The bot's `handle_event/2` callback is called with the event type and payload.
  2. The bot processes the event and can take actions such as replying, liking a post, or logging information.

  ## Notes

  - The polling strategy fetches the bot's notifications periodically, while the firehose
    strategy streams real-time repo events; see `ProtoRune.Bot.Firehose` for the events it
    dispatches.
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

  @callback get_identifier :: String.t()
  @callback get_password :: String.t()

  @callback handle_event(event :: atom(), data :: map()) :: {:ok, term} | {:error, term}

  @spec __using__(Server.options_t()) :: Macro.t()
  defmacro __using__(opts) do
    quote do
      @behaviour ProtoRune.Bot

      def start_link do
        Server.start_link(unquote(opts))
      end

      # Default implementation for the optional event callback
      @impl ProtoRune.Bot
      def handle_event(_, _), do: :ok

      defoverridable handle_event: 2
    end
  end
end
