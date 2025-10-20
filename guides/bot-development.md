# Bot Development

ProtoRune provides a bot framework built on OTP principles for creating reliable, event-driven bots that respond to notifications.

## Creating Your First Bot

A bot is a module that uses `ProtoRune.Bot` and implements event handlers:

```elixir
defmodule GreeterBot do
  use ProtoRune.Bot,
    name: __MODULE__,
    strategy: :polling

  require Logger

  @impl true
  def get_identifier, do: System.get_env("BOT_IDENTIFIER")

  @impl true
  def get_password, do: System.get_env("BOT_PASSWORD")

  @impl true
  def handle_event(:mention, payload) do
    Logger.info("Got mentioned by #{payload.author.handle}")
    {:ok, :processed}
  end

  @impl true
  def handle_event(_event, _payload) do
    {:ok, :ignored}
  end
end
```

Start the bot:

```elixir
{:ok, pid} = GreeterBot.start_link()
```

## Bot Configuration

### Required Options

When using `ProtoRune.Bot`, provide these options:

- `:name` - Module name or atom identifying the bot
- `:strategy` - Notification strategy (`:polling` or `:firehose`)

### Optional Options

- `:service` - Service URL (default: "https://bsky.social")
- `:langs` - List of supported languages (default: `["en"]`)
- `:identifier` - Bot's login identifier (or implement `get_identifier/0`)
- `:password` - Bot's app password (or implement `get_password/0`)
- `:polling` - Polling configuration (see Polling Strategy section)

## Required Callbacks

### `get_identifier/0`

Returns the bot's login identifier (handle or email):

```elixir
@impl true
def get_identifier do
  System.get_env("BOT_IDENTIFIER") || "bot.bsky.social"
end
```

### `get_password/0`

Returns the bot's app password:

```elixir
@impl true
def get_password do
  System.get_env("BOT_PASSWORD")
end
```

### `handle_event/2`

Processes events dispatched to the bot:

```elixir
@impl true
def handle_event(event, payload) do
  # Process the event
  {:ok, result}
end
```

Return values:

- `{:ok, term}` - Event processed successfully
- `{:error, term}` - Event processing failed

## Event Types

The bot receives these event types from notifications:

### `:mention`

Triggered when someone mentions the bot:

```elixir
@impl true
def handle_event(:mention, payload) do
  # payload contains the post that mentioned you
  author = payload.thread.post.author
  text = payload.thread.post.record.text

  Logger.info("Mentioned by #{author.handle}: #{text}")
  {:ok, :handled}
end
```

### `:reply`

Triggered when someone replies to the bot's post:

```elixir
@impl true
def handle_event(:reply, payload) do
  # payload contains the reply thread
  reply_post = payload.thread.post

  Logger.info("Got reply from #{reply_post.author.handle}")
  {:ok, :handled}
end
```

### `:like`

Triggered when someone likes the bot's content:

```elixir
@impl true
def handle_event(:like, payload) do
  user = payload.user
  subject = payload.subject

  Logger.info("#{user.handle} liked our post")
  {:ok, :handled}
end
```

### `:repost`

Triggered when someone reposts the bot's content:

```elixir
@impl true
def handle_event(:repost, payload) do
  user = payload.user
  post = payload.post

  Logger.info("#{user.handle} reposted our content")
  {:ok, :handled}
end
```

### `:follow`

Triggered when someone follows the bot:

```elixir
@impl true
def handle_event(:follow, payload) do
  user = payload.user

  Logger.info("New follower: #{user.handle}")
  {:ok, :handled}
end
```

### `:quote`

Triggered when someone quotes the bot's post:

```elixir
@impl true
def handle_event(:quote, payload) do
  thread = payload.thread

  Logger.info("Got quoted")
  {:ok, :handled}
end
```

### `:error`

Triggered when an error occurs during event processing:

```elixir
@impl true
def handle_event(:error, payload) do
  reason = payload.reason

  Logger.error("Bot error: #{inspect(reason)}")
  {:ok, :logged}
end
```

## Polling Strategy

The polling strategy fetches notifications at regular intervals.

### Basic Polling Configuration

```elixir
defmodule MyBot do
  use ProtoRune.Bot,
    name: __MODULE__,
    strategy: :polling,
    polling: %{
      interval: 30,  # Check every 30 seconds
      process_from: ~N[2024-01-01 00:00:00]  # Start from this date
    }

  # ... callbacks ...
end
```

### Polling Options

- `:interval` - Seconds between polls (default: 5)
- `:process_from` - Start processing from this NaiveDateTime (default: now)

### How Polling Works

1. Bot starts and authenticates
2. Polling process begins fetching notifications
3. New notifications are converted to events
4. Events are dispatched to `handle_event/2`
5. Process waits for interval duration
6. Repeat from step 2

### Rate Limiting

The poller implements exponential backoff when rate limited:

```elixir
# Initial interval: 5 seconds
# On rate limit: 5² = 25 seconds
# Next attempt: 25² = 625 seconds (10.4 minutes)
# Max backoff: 5 minutes
```

## Responding to Events

Bots can respond to events by calling ProtoRune.Bsky functions:

### Replying to Mentions

```elixir
@impl true
def handle_event(:mention, payload) do
  session = get_session()  # Retrieve bot's session
  mention_uri = payload.thread.post.uri
  author = payload.thread.post.author.handle

  {:ok, _reply} = ProtoRune.Bsky.post(
    session,
    "Thanks for the mention, @#{author}!",
    reply_to: mention_uri
  )

  {:ok, :replied}
end
```

### Following Back

```elixir
@impl true
def handle_event(:follow, payload) do
  session = get_session()
  follower_did = payload.user.did

  {:ok, _follow} = ProtoRune.Bsky.follow(session, follower_did)

  {:ok, :followed_back}
end
```

### Liking Replies

```elixir
@impl true
def handle_event(:reply, payload) do
  session = get_session()
  reply = payload.thread.post

  {:ok, _like} = ProtoRune.Bsky.like(session, reply.uri, reply.cid)

  {:ok, :liked}
end
```

## Managing Bot State

Bots run as GenServers, so you can maintain custom state:

```elixir
defmodule StatefulBot do
  use ProtoRune.Bot,
    name: __MODULE__,
    strategy: :polling

  @impl true
  def get_identifier, do: System.get_env("BOT_IDENTIFIER")

  @impl true
  def get_password, do: System.get_env("BOT_PASSWORD")

  # Keep track of mentions
  @impl true
  def handle_event(:mention, payload) do
    count = get_mention_count() + 1
    put_mention_count(count)

    if rem(count, 10) == 0 do
      session = get_session()
      ProtoRune.Bsky.post(session, "Received #{count} mentions so far!")
    end

    {:ok, count}
  end

  @impl true
  def handle_event(_event, _payload), do: {:ok, :ignored}

  # State management helpers (you need to implement these)
  defp get_mention_count, do: :persistent_term.get({__MODULE__, :mentions}, 0)
  defp put_mention_count(count), do: :persistent_term.put({__MODULE__, :mentions}, count)
  defp get_session, do: :persistent_term.get({__MODULE__, :session})
end
```

Note: The current bot framework doesn't expose the session directly to handlers. You may need to extend the framework or use process dictionary for state management in the MVP.

## Supervision

Add bots to your supervision tree for reliability:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      GreeterBot,
      ResponderBot,
      MonitorBot
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

If a bot crashes, the supervisor will restart it automatically.

## Best Practices

### Environment Variables for Credentials

Never hardcode credentials:

```elixir
# Good
def get_identifier, do: System.get_env("BOT_IDENTIFIER")
def get_password, do: System.get_env("BOT_PASSWORD")

# Bad
def get_identifier, do: "mybot.bsky.social"  # Never do this
def get_password, do: "password123"          # Never do this
```

### Graceful Error Handling

Always handle errors in event processing:

```elixir
@impl true
def handle_event(:mention, payload) do
  case process_mention(payload) do
    {:ok, result} ->
      {:ok, result}

    {:error, reason} ->
      Logger.error("Failed to process mention: #{inspect(reason)}")
      {:ok, :failed}  # Return ok to continue processing other events
  end
end
```

### Rate Limit Awareness

Be mindful of API rate limits:

```elixir
@impl true
def handle_event(:mention, payload) do
  # Check if we've responded recently
  if should_respond?(payload) do
    respond_to_mention(payload)
  else
    Logger.info("Skipping mention to avoid rate limits")
  end

  {:ok, :handled}
end
```

### Logging

Use structured logging for bot operations:

```elixir
@impl true
def handle_event(event, payload) do
  Logger.metadata(bot: __MODULE__, event: event)
  Logger.info("Processing event", event: event, author: payload[:author])

  # ... process event ...

  {:ok, :processed}
end
```

## Testing Bots

Test bots with mock sessions:

```elixir
defmodule GreeterBotTest do
  use ExUnit.Case

  test "responds to mentions" do
    mock_payload = %{
      thread: %{
        post: %{
          uri: "at://test/post/123",
          author: %{handle: "alice.bsky.social"},
          record: %{text: "Hello @bot"}
        }
      }
    }

    {:ok, result} = GreeterBot.handle_event(:mention, mock_payload)
    assert result == :replied
  end
end
```

## Debugging

Monitor bot activity:

```elixir
# Check bot process
Process.info(Process.whereis(GreeterBot))

# View bot state
:sys.get_state(GreeterBot)

# Trace messages
:sys.trace(GreeterBot, true)
```

## Future Enhancements

Features planned for future releases:

- **Firehose strategy** - Real-time event streaming
- **Jetstream support** - Filtered event streams
- **State persistence** - Automatic state saving/loading
- **Message filtering** - Pattern-based event filtering
- **Telemetry integration** - Built-in metrics
- **Multi-account bots** - Single bot managing multiple accounts

See the roadmap for implementation timelines.
