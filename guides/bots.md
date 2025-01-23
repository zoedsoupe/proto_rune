# Bot Development with ProtoRune

## Creating a Bot

A bot in ProtoRune is an OTP process that handles events from the ATProto network. 

```elixir
defmodule MyBot do
  use ProtoRune.Bot,
    name: :my_bot,
    strategy: :polling,
    service: "https://bsky.social" # defaults to the config service

  @impl true
  def get_identifier, do: System.fetch_env!("BOT_IDENTIFIER")
  def get_password, do: System.fetch_env!("BOT_PASSWORD")
  
  @impl true
  def handle_event(:like, %{uri: uri, user: user}) do
    Logger.info("Got like from #{user.handle}")
  end
end
```

## Event Types

Bots receive these event types:

```elixir
@type event ::
  :like |    # Someone liked bot's post
  :reply |   # Reply to bot's post
  :mention | # Bot was mentioned
  :repost |  # Bot's post was reposted
  :quote |   # Bot's post was quoted
  :follow    # Bot gained a follower
```

## Event Payloads

Each event receives relevant data:

```elixir
 @type user :: %{
   did: String.t(),
   handle: String.t(), 
   display_name: String.t() | nil,
   avatar_url: String.t() | nil
 }

 @type like_payload :: %{
   uri: String.t(),          # URI of the liked post
   user: user(),             # User who liked the post 
   post: ProtoRune.Bsky.Post.t(),  # The post that was liked
   created_at: DateTime.t()   # When the like happened
 }

 @type reply_payload :: %{
   uri: String.t(),          # URI of the reply post
   user: user(),             # User who replied
   post: ProtoRune.Bsky.Post.t(),  # The reply post
   reply_to: ProtoRune.Bsky.Post.t(), # Original post being replied to
   created_at: DateTime.t()   # When the reply happened
 }

 @type mention_payload :: %{
   uri: String.t(),          # URI of post containing mention
   user: user(),             # User who mentioned the bot
   post: ProtoRune.Bsky.Post.t(),  # Post containing the mention
   created_at: DateTime.t()   # When the mention happened
 }

 @type repost_payload :: %{
   uri: String.t(),          # URI of the repost 
   user: user(),             # User who reposted
   post: ProtoRune.Bsky.Post.t(),  # Original post that was reposted
   created_at: DateTime.t()   # When the repost happened
 }

 @type quote_payload :: %{
   uri: String.t(),          # URI of the quote post
   user: user(),             # User who quoted
   post: ProtoRune.Bsky.Post.t(),  # The quote post
   quoted_post: ProtoRune.Bsky.Post.t(), # Original post being quoted
   created_at: DateTime.t()   # When the quote happened
 }

 @type follow_payload :: %{
   uri: String.t(),          # URI of the follow
   user: user(),             # User who followed
   created_at: DateTime.t()   # When the follow happened
 }
```

## Strategies

ProtoRune bots can use one of two strategies to receive events and notifications:

1. Polling 
<!-- 2. Firehose (real-time subscription) -->

Let's dive into each of these in more depth.

### Polling Strategy

The polling strategy periodically checks the AT Proto notifications endpoint for new events and notifications. You can specify the polling interval in miliseconds. 

Here's an example of configuring a bot to use the polling strategy:

```elixir
use ProtoRune.Bot,
  strategy: :polling,
  polling: %{
    interval: :timer.seconds(30),     # Poll every 30 seconds
    process_from: DateTime.utc_now()  # Start processing events from the current time
  }
```

Some key things to understand about the polling strategy:

- It allows you to control the frequency of checking for new events via the `interval` parameter. A shorter interval means more "real-time"-like behavior but also more requests to the server. A longer interval is easier on server resources but means a delay in processing events.

- The `process_from` parameter lets you specify a start time for event processing. This is useful if you want to ignore old events when first starting the bot. By default it will process all historical events.

- Polling is a simple approach to implement and reason about. However, for high volume bots or cases where minimizing latency is critical, the firehose strategy may be a better fit.

- If the AT Proto server being used is experiencing issues or slow to respond, a polling bot will just keep retrying on its regular interval. Make sure your polling frequency isn't too aggressive.

<!-- ### Firehose Strategy -->

<!-- The firehose strategy opens a persistent connection to a relay server to receive a real-time stream of events as they occur. --> 

<!-- Here's how you would configure a firehose bot: -->

<!-- ```elixir -->
<!-- use ProtoRune.Bot, -->  
  <!-- strategy: :firehose, -->
  <!-- firehose: %{ -->
    <!-- relay_uri: "wss://bsky.network", -->
    <!-- filters: ["app.bsky.feed.*"], -->  
    <!-- cursor: "latest" -->
  <!-- } -->
<!-- ``` -->

<!-- Some important aspects of the firehose approach: -->

<!-- - You specify the `relay_uri` of the server to connect to. This should be a WebSocket (`ws://` or `wss://`) URL. --> 

<!-- - The `filters` option lets you specify which types of events you want to receive. This uses a glob pattern matching the event schemas. For example `["app.bsky.feed.*"]` will match all feed related events. Omitting `filters` or passing `["*"]` will match all events. -->

<!-- - The `cursor` specifies where in the event stream to start consuming from. By default it starts with the `"latest"` events. You can also pass a specific event sequence ID to start from. -->

<!-- - Firehose provides events with lower latency than polling, since events are pushed immediately as they occur. This is ideal for bots that need to respond in real-time. -->

<!-- - If the WebSocket connection is lost, the bot will automatically attempt to reconnect with exponential backoff. However, events may be missed in between reconnection attempts, so mission critical bots may want to implement additional resiliency. -->

<!-- - Firehose can be more efficient than polling for high throughput, since a single connection is used. But it does require more server resources to maintain an open connection per bot. -->

## Which Strategy to Choose?

The choice between polling and firehose depends on your bot's specific needs:

- For bots that don't require immediate event processing and aim to be very simple, polling is a good choice. It's also a good starting point when developing a new bot.

- For bots that need low latency processing, handle a high volume of events, or implement any real-time features, firehose is the way to go. Examples could be chat bots, moderation bots, or notification bots.

<!-- - Consider the operational burden as well. Firehose bots are a bit more complex to run and monitor, due to the persistent connections. Polling bots are simpler but may generate a lot of requests. -->

## Bot State

Store state in the bot process:

```elixir
defmodule StatefulBot do
  use ProtoRune.Bot
  
  @impl true
  def init(_opts) do
    {:ok, %{replies: 0}}
  end

  @impl true
  def handle_event(:reply, _payload, state) do
    new_state = Map.update!(state, :replies, & &1 + 1)
    {:ok, new_state}
  end
end
```

## Running Multiple Bots

Each bot is a supervised process so you can manage multiple of them with a Supervisor:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      GreeterBot,
      ModeratorBot,
      AnalyticsBot
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Error Handling

The bot will automatically:
- Retry on rate limits with backoff
- Refresh expired sessions
- Reconnect on connection loss
- Log errors

Handle specific errors in events:

```elixir
def handle_event(:reply, payload, state) do
  case reply_to_mention(payload) do
    {:ok, _} -> {:ok, state}
    {:error, :rate_limited} -> {:retry, state} 
    {:error, _} = err -> err
  end
end
```
