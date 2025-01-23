<p align="center">
  <h1>ProtoRune</h1>
  <p><strong>A type-safe, well-documented AT Protocol SDK and bot framework for Elixir</strong></p>
</p>

> [!WARNING]
>
> This library is under active development and isn't production ready, expect breaking chnages

## Installation

```elixir
def deps do
  [
    {:proto_rune, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Create a session
{:ok, session} = ProtoRune.create_session("handle.bsky.social", "app-password")

# Post something
{:ok, post} = ProtoRune.Client.create_post(session, "Hello from Elixir!")

# Create a bot
defmodule MyBot do
  use ProtoRune.Bot, name: :my_bot, strategy: :polling

  @impl true
  def handle_event(:like, %{uri: uri, user: user}) do
    # Handle like event
  end
end

MyBot.start_link()
```

## Examples

- [Simple bot with event handling](examples/simple_bot.ex)
- [Post with rich text and embeds](examples/rich_post.ex) 
- [Custom feed generator](examples/feed_generator.ex)
- [Firehose subscription](examples/firehose.ex)

## Architecture

ProtoRune is organized into focused modules:

- `ATProto` - Core protocol implementation (repo, identity, etc)
- `Bsky` - Bluesky-specific features (feed, graph, notifications) 
- `Bot` - Bot framework with polling/firehose support
- `XRPC` - Low-level XRPC client
- `Lexicons` - Generated code from AT Protocol lexicons

> Other submodules do exist like `ProtoRune.HTTPClient` but it are to be used internally

## Documentation

Full documentation is available at [hexdocs.pm/proto_rune](https://hexdocs.pm/proto_rune).

The guide covers:
- [Getting Started](guides/getting_started.md)
- [Bot Development](guides/bots.md)
- [Working with Records](guides/records.md)
- [XRPC Client Usage](guides/xrpc.md)
- [Identity Management](guides/identity.md)

## Contributing

Pull requests welcome! See our [Contributing Guide](CONTRIBUTING.md).

## Inspirations

1. [Skyware](https://skyware.js.org/)
2. [atcute](https://github.com/mary-ext/atcute)
3. [Python AT Proto SDK](https://github.com/MarshalX/atproto)

## License

MIT License - see [LICENSE](./LICENSE) for details.
