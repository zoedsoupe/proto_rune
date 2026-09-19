# Bot Development

`ProtoRune.Bot` is an OTP-based framework for event-driven bots that react to notifications. Bots are processes, so they fit into your supervision tree like anything else.

## A bot

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
    Logger.info("Mentioned by #{payload.thread.post.author.handle}")
    {:ok, :handled}
  end

  def handle_event(_event, _payload), do: {:ok, :ignored}
end
```

```elixir
{:ok, pid} = GreeterBot.start_link()
```

## Options

Required:

- `:name`: module name or atom
- `:strategy`: `:polling` or `:firehose` (see `ProtoRune.Bot.Firehose`)

Optional:

- `:service`: PDS URL (default `"https://bsky.social"`)
- `:langs`: supported languages (default `["en"]`)
- `:identifier` / `:password`: instead of the callbacks
- `:polling`: polling config (below)

## Callbacks

- `get_identifier/0`: login handle or email
- `get_password/0`: app password
- `handle_event/2`: returns `{:ok, term}` or `{:error, term}`

Get credentials from env vars, never hardcode them.

## Events

Dispatched from notifications:

| Event | Payload |
|---|---|
| `:mention` | `payload.thread.post` with the mentioning post |
| `:reply` | `payload.thread.post` with the reply |
| `:like` | `payload.user`, `payload.subject` |
| `:repost` | `payload.user`, `payload.post` |
| `:follow` | `payload.user` |
| `:quote` | `payload.thread` |
| `:error` | `payload.reason` |

## Polling

```elixir
defmodule MyBot do
  use ProtoRune.Bot,
    name: __MODULE__,
    strategy: :polling,
    polling: %{
      interval: 30,                          # seconds between polls (default 5)
      process_from: ~N[2024-01-01 00:00:00]  # ignore notifications before this (default: now)
    }

  # callbacks...
end
```

The poller authenticates, fetches notifications, dispatches new ones as events, waits, repeats. On rate limiting it backs off exponentially, capped at 5 minutes.

## Responding to events

Call `ProtoRune.Bsky` from your handlers:

```elixir
@impl true
def handle_event(:follow, payload) do
  session = get_session()
  {:ok, _} = ProtoRune.Bsky.follow(session, payload.user.did)
  {:ok, :followed_back}
end
```

Note: the framework doesn't expose the session directly to handlers yet. Keep it in `:persistent_term` or extend the framework; this improves in a future version.

## Supervision

```elixir
children = [
  GreeterBot,
  ResponderBot
]

Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
```

A crashed bot is restarted automatically.

## Error handling in handlers

Return `{:ok, _}` even on failure so one bad event doesn't stop the bot:

```elixir
@impl true
def handle_event(:mention, payload) do
  case process_mention(payload) do
    {:ok, result} -> {:ok, result}
    {:error, reason} ->
      Logger.error("Failed to process mention: #{inspect(reason)}")
      {:ok, :failed}
  end
end
```

## Testing

Handlers are plain functions, test them with mock payloads:

```elixir
test "responds to mentions" do
  payload = %{
    thread: %{
      post: %{
        uri: "at://test/post/123",
        author: %{handle: "alice.bsky.social"},
        record: %{text: "Hello @bot"}
      }
    }
  }

  assert {:ok, :replied} = GreeterBot.handle_event(:mention, payload)
end
```
