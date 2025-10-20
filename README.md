# ProtoRune

A type-safe Elixir SDK for the AT Protocol with a built-in bot framework.

> **Status**: v0.2.0 MVP - Core features complete, production ready for basic use cases.

## What is ProtoRune?

ProtoRune provides Elixir developers with tools to build applications on the AT Protocol, the decentralized social networking protocol that powers Bluesky.

Key features:

- **Type-safe API**: Generated from official AT Protocol lexicons
- **Explicit session management**: Functional approach with no hidden global state
- **Rich text support**: Builder for mentions, links, and hashtags with automatic byte offset calculation
- **Bot framework**: OTP-based event-driven bots with polling strategy
- **Complete Bluesky operations**: Post, like, repost, follow, block, notifications, and more
- **Identity resolution**: DID and handle resolution with caching

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:proto_rune, "~> 0.2.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### Posting to Bluesky

```elixir
# Login with your handle and app password
{:ok, session} = ProtoRune.login(
  "your-handle.bsky.social",
  "your-app-password"
)

# Post something
{:ok, post} = ProtoRune.Bsky.post(session, "Hello from Elixir!")
```

### Rich Text with Mentions

```elixir
alias ProtoRune.RichText

{:ok, rt} =
  RichText.new()
  |> RichText.text("Hello ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text("! Check out ")
  |> RichText.link("ProtoRune", "https://github.com/zoedsoupe/proto_rune")
  |> RichText.text(" ")
  |> RichText.hashtag("elixir")
  |> RichText.build()

{:ok, post} = ProtoRune.Bsky.post(session, rt)
```

### Building a Bot

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
    Logger.info("Got mentioned by #{payload.thread.post.author.handle}")
    {:ok, :handled}
  end

  @impl true
  def handle_event(_event, _payload) do
    {:ok, :ignored}
  end
end

# Start the bot
{:ok, pid} = GreeterBot.start_link()
```

## Core Concepts

### Sessions

Sessions contain authentication tokens and account information. All operations require a session:

```elixir
# Create session
{:ok, session} = ProtoRune.login(identifier, password)

# Session contains:
# - access_jwt: Access token
# - refresh_jwt: Refresh token
# - did: Your decentralized identifier
# - handle: Your handle
# - service_url: Your PDS URL

# Refresh when needed
{:ok, fresh_session} = ProtoRune.refresh_session(session)
```

### Identity Resolution

Work with DIDs (decentralized identifiers) and handles:

```elixir
# Resolve handle to DID
{:ok, did} = ProtoRune.resolve_handle("alice.bsky.social")
# => "did:plc:abc123xyz"

# Resolve DID to document
{:ok, doc} = ProtoRune.resolve_did("did:plc:abc123xyz")

# Validate handle-to-DID binding
{:ok, doc} = ProtoRune.validate_identity("alice.bsky.social")
```

### Social Operations

High-level functions for common Bluesky operations:

```elixir
# Social interactions
{:ok, like} = ProtoRune.Bsky.like(session, post.uri, post.cid)
{:ok, repost} = ProtoRune.Bsky.repost(session, post.uri, post.cid)
{:ok, follow} = ProtoRune.Bsky.follow(session, "alice.bsky.social")

# Reading content
{:ok, timeline} = ProtoRune.Bsky.get_timeline(session, limit: 20)
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "bob.bsky.social")
{:ok, thread} = ProtoRune.Bsky.get_post_thread(session, post_uri)

# Notifications
{:ok, notifs} = ProtoRune.Bsky.list_notifications(session)
{:ok, %{count: unread}} = ProtoRune.Bsky.get_unread_count(session)

# Moderation
{:ok, block} = ProtoRune.Bsky.block(session, "spammer.bsky.social")
{:ok, _} = ProtoRune.Bsky.mute(session, "noisy.bsky.social")
```

## Architecture

ProtoRune follows AT Protocol's layered architecture:

```
ProtoRune (Public API)
    |
    +-- ProtoRune.Bsky (Bluesky high-level helpers)
    |       |
    |       +-- Actor (profiles)
    |       +-- Feed (posts, timeline)
    |       +-- Graph (follows, blocks)
    |       +-- Notification (notifications)
    |
    +-- ProtoRune.Atproto (Protocol layer)
    |       |
    |       +-- Identity (DID/handle resolution)
    |       +-- Repo (repository operations)
    |       +-- Server (session management)
    |
    +-- ProtoRune.XRPC (Transport layer)
    |
    +-- ProtoRune.Bot (Bot framework)
```

## Development Setup

Clone with submodules to get AT Protocol lexicons:

```bash
git clone --recurse-submodules https://github.com/zoedsoupe/proto_rune.git
cd proto_rune

# Install dependencies
mix deps.get

# Run tests
mix test
```

## Design Principles

ProtoRune follows these principles:

1. **Explicit over implicit**: Pass sessions explicitly, no hidden global state
2. **Type safety**: Runtime validation with compile-time type specs
3. **OTP native**: Leverage GenServers and Supervisors for reliability
4. **Progressive disclosure**: Simple tasks are simple, complex tasks are possible
5. **ATProto alignment**: Reflect the protocol's layered architecture

## Roadmap

**Completed (v0.2.0 MVP)**:
- Lexicon code generation
- XRPC client with explicit sessions
- ATProto layer (identity, repo, server)
- Bluesky high-level API
- Rich text builder
- Bot framework with polling

**Planned**:
- OAuth support (v0.3.0)
- Firehose real-time events (v0.3.0)
- Jetstream integration (v0.4.0)
- Feed generator SDK (v0.4.0)
- Image and video upload (v0.4.0)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass (`mix test`)
5. Format code (`mix format`)
6. Submit a pull request

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidelines.

## Inspirations

ProtoRune draws inspiration from:

- [atcute](https://github.com/mary-ext/atcute) - Lightweight TypeScript ATProto library
- [jacquard](https://github.com/nonbinary-computer/jacquard) - High-performance Rust implementation

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/zoedsoupe/proto_rune/issues)
- **Documentation**: [guides/](guides/) and [hexdocs.pm/proto_rune](https://hexdocs.pm/proto_rune)

Built love by [@zoedsoupe](https://github.com/zoedsoupe).
