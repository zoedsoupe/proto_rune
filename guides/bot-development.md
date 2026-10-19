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
- `:strategy`: `:polling`, `:firehose` or `:jetstream` (see below)

Optional:

- `:service`: PDS URL (default `"https://bsky.social"`)
- `:identifier` / `:password`: instead of the callbacks
- `:polling`: polling config (below)
- `:firehose` / `:jetstream`: stream configs (below)

## Callbacks

- `get_identifier/0`: login handle or email
- `get_password/0`: app password
- `handle_event/2`: returns `{:ok, term}` or `{:error, term}`
- `handle_event/3`: same as `handle_event/2`, plus the bot's session as the
  third argument, for handlers that need to call the API

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

The poller authenticates, fetches notifications, dispatches new ones as events, waits, repeats. On rate limiting it backs off exponentially, capped at 5 minutes. Only the first page of notifications is fetched per cycle, so keep `:interval` shorter than the time it takes notifications to pile up.

## Streams

The `:firehose` and `:jetstream` strategies stream repo events as they happen instead of polling:

- `:firehose` (`ProtoRune.Bot.Firehose`) subscribes to the entire network and decodes every CAR block of every commit, with no backpressure: every operation is sent to your handler serially. Use it only with fast handlers.
- `:jetstream` (`ProtoRune.Bot.Jetstream`) connects to a Jetstream instance, which filters server-side (`wanted_collections` / `wanted_dids`) and ships plain JSON text frames. It is the right default for bots doing real work per event.

```elixir
defmodule MyBot do
  use ProtoRune.Bot,
    name: __MODULE__,
    strategy: :jetstream,
    jetstream: %{
      wanted_collections: ["app.bsky.feed.post"],  # default: all
      wanted_dids: ["did:plc:..."]                 # default: all
    }

  # callbacks...
end
```

Both dispatch `:commit` events (one per repository operation, with `:repo`, `:rev`, `:seq`, `:time`, `:action`, `:path`, `:cid` and `:record`) plus stream-level events (`:identity`, `:account`).

## Responding to events

Implement `handle_event/3` when your handler needs the session:

```elixir
@impl true
def handle_event(:follow, payload, session) do
  {:ok, _} = ProtoRune.Bsky.follow(session, payload.user.did)
  {:ok, :followed_back}
end

def handle_event(event, payload, _session), do: handle_event(event, payload)
```

The session passed in is the bot's authenticated session, kept fresh by the server. `handle_event/2` keeps working for handlers that never call the API.

## Supervision

```elixir
children = [
  GreeterBot,
  ResponderBot
]

Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
```

The generated `child_spec/1` uses the bot's `:name` as the child id, so each bot module in the example runs as its own supervised child. A crashed bot is restarted automatically.

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
