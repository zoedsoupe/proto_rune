defmodule ProtoRune.Bot do
  @moduledoc """
  The `ProtoRune.Bot` module provides the foundational behavior and macros for building bots
  in the ProtoRune ecosystem. It defines the basic structure for bots and ensures that every bot
  adheres to a consistent interface, with customizable event handling, identifier, and password
  retrieval.

  The bot system integrates with the `ProtoRune.Bot.Server` to manage bot lifecycles, handle
  events, and manage sessions. Bots can use different strategies for receiving notifications,
  such as polling or firehose (currently under development).

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

  - **`:reply`**
    - Triggered when someone replies to a post involving the bot.
    - **Payload**:
      - `:uri` - The URI of the post that was replied to.
      - `:user` - The user who made the reply.
      - `:content` - The content of the reply post.

    Example payload:
    ```elixir
    %{uri: "at://did:plc:1234", user: "user123", content: "Thanks for your post!"}
    ```

  - **`:quote`**
    - Triggered when someone quotes the bot's post.
    - **Payload**:
      - `:uri` - The URI of the quoted post.
      - `:user` - The user who quoted the post.
      - `:content` - The content of the quote.

    Example payload:
    ```elixir
    %{uri: "at://did:plc:1234", user: "user456", content: "Great article!"}
    ```

  - **`:mention`**
    - Triggered when the bot is mentioned in a post.
    - **Payload**:
      - `:uri` - The URI of the post mentioning the bot.
      - `:user` - The user who mentioned the bot.
      - `:content` - The content of the post where the bot was mentioned.

    Example payload:
    ```elixir
    %{uri: "at://did:plc:5678", user: "user789", content: "Check out @bot's post!"}
    ```

  - **`:like`**
    - Triggered when someone likes a post by the bot.
    - **Payload**:
      - `:uri` - The URI of the liked post.
      - `:user` - The user who liked the post.
      - `:subject` - The subject of the post that was liked (full post data).

    Example payload:
    ```elixir
    %{uri: "at://did:plc:1234", user: "user123", subject: %{content: "Nice post!"}}
    ```

  - **`:repost`**
    - Triggered when someone reposts content from the bot.
    - **Payload**:
      - `:uri` - The URI of the reposted content.
      - `:user` - The user who reposted the content.
      - `:post` - The post that was reposted (full post data).

    Example payload:
    ```elixir
    %{uri: "at://did:plc:5678", user: "user987", post: %{content: "Check this out!"}}
    ```

  - **`:follow`**
    - Triggered when someone follows the bot.
    - **Payload**:
      - `:uri` - The URI of the follow event.
      - `:user` - The user who followed the bot.

    Example payload:
    ```elixir
    %{uri: "at://did:plc:9876", user: "user123"}
    ```

  - **`:error`**
    - Triggered when there is an error while processing an event (e.g., failed to fetch a post).
    - **Payload**:
      - `:reason` - An atom describing the error.

    Example payload:
    ```elixir
    %{reason: {:rate_limited, retry_adter :: integer}}
    ```

  ## Callbacks

  The following callbacks can be implemented by any bot module that uses `ProtoRune.Bot`:

  - `get_identifier/0`: Retrieves the bot's identifier (e.g., username or email). This is used
    for logging into the service.

  - `get_password/0`: Retrieves the bot's password. This is used alongside the identifier
    to authenticate the bot.

  - `handle_event/2`: Handles events that are dispatched to the bot. These events can include
    mentions, replies, likes, and other interactions that the bot should process.

  The `handle_event/2` function receives:
  - `event`: An atom that represents the type of event (e.g., `:mention`, `:like`, `:reply`).
  - `payload`: A map containing the data related to the event, such as the URI of the post or the user who triggered the event.

  ## Optional Callbacks

  These callbacks are optional and can be overridden by the bot module:

  - `get_identifier/0`: If not implemented, a default error will be raised indicating the callback must be defined.
  - `get_password/0`: Similar to `get_identifier/0`, this must be implemented by the bot if needed for authentication.

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

  - The current implementation supports the polling strategy for fetching notifications. Firehose-based notifications are not yet implemented.
  - Bots should be designed to handle events and messages in a non-blocking manner for efficient performance.
  """

  alias ProtoRune.Bot.Server

  @callback get_identifier :: String.t()
  @callback get_password :: String.t()

  @callback handle_event(event :: atom(), data :: map()) :: {:ok, term} | {:error, term}

  @optional_callbacks get_identifier: 0, get_password: 0

  @spec __using__(Server.options_t()) :: Macro.t()
  defmacro __using__(opts) do
    quote do
      @behaviour ProtoRune.Bot

      def start_link do
        Server.start_link(unquote(opts))
      end

      # Default implementation for optional callbacks
      @impl ProtoRune.Bot
      def handle_event(_, _), do: :ok

      @impl ProtoRune.Bot
      def get_identifier, do: raise("get_identifier/0 not implemented")

      @impl ProtoRune.Bot
      def get_password, do: raise("get_password/0 not implemented")

      # Required callback
      defoverridable handle_event: 2, get_identifier: 0, get_password: 0
    end
  end
end
