# RFC: ATProtocol SDK Implementation for Elixir (proto_rune)

## Abstract

This RFC proposes a comprehensive implementation of the AT Protocol SDK for Elixir, building upon the existing proto_rune library. The implementation will provide feature parity with the JavaScript SDK while leveraging Elixir's strengths in concurrent processing, fault tolerance, and functional programming paradigms.

## Status

Draft

## Background

The proto_rune library currently provides schema generation capabilities based on Bluesky lexicon definitions. This proposal aims to extend the library to include a full AT Protocol SDK implementation, including a bot framework, XRPC client, firehose support, and other essential features.

## Goals

- Provide a native Elixir implementation of the AT Protocol
- Create an intuitive bot framework with support for both polling and firehose
- Maintain feature parity with the JavaScript SDK
- Leverage Elixir's concurrency model and OTP principles
- Ensure type safety through generated structs and specs
- Provide a minimal DSL for common operations

## Non-Goals

- Implementation of custom lexicon definitions
- Web interface or dashboard for bot management
- Direct compatibility with JavaScript SDK plugins

## Architecture Overview

### Core Components

1. **XRPC Client**
   - HTTP client wrapper with ATP-specific middleware
   - Automatic retry mechanisms with exponential backoff
   - Rate limiting handling
   - Session management and auth token caching

2. **Repository Layer**
   - CRUD operations for repository data
   - Commit handling and synchronization
   - CAR file processing
   - Data validation using generated schemas

3. **Subscription System**
   - Firehose connection management
   - Event filtering and routing
   - Backpressure handling
   - Connection recovery

4. **Bot Framework**
   - Behavior definitions for bot implementations
   - Event handling system
   - State management
   - Supervised bot processes

### Component Details

#### XRPC Client

```elixir
defmodule ProtoRune.XRPC do
  @type options :: [
    base_url: String.t(),
    timeout: integer(),
    retry_count: integer(),
    retry_delay: integer()
  ]

  @callback query(procedure :: String.t(), params :: map(), opts :: options()) :: 
    {:ok, term()} | {:error, term()}
  
  @callback procedure(procedure :: String.t(), data :: map(), opts :: options()) ::
    {:ok, term()} | {:error, term()}
end
```

#### Bot Framework Core

```elixir
defmodule ProtoRune.Bot do
  @type strategy :: :polling | :firehose
  @type bot_config :: [
    name: module(),
    strategy: strategy(),
    polling_interval: integer(),
    max_retries: integer()
  ]
end
```

#### Event System

```elixir
defmodule ProtoRune.Events do
  @type event_type :: :post | :like | :repost | :follow | :profile_update
  @type event :: {event_type(), map()}
  @type handler :: (event() -> any())
end
```

## Public API

### Bot Definition

```elixir
defmodule MyBot do
  use ProtoRune.Bot,
    strategy: :firehose,
    filters: ["app.bsky.feed.post", "app.bsky.feed.like"]

  # Required callbacks
  def handle_event(:post, payload) do
    # Handle post event
  end

  def handle_event(:like, payload) do
    # Handle like event
  end

  # Optional initialization
  def init do
    # Setup bot state
  end
end
```

### Repository Operations

```elixir
# Create a post
ProtoRune.post("Hello, World!")
|> ProtoRune.with_images(["/path/to/image.jpg"])
|> ProtoRune.publish()

# Query the repository
ProtoRune.Repository.list_records("app.bsky.feed.post", limit: 10)
```

### Firehose Subscription

```elixir
ProtoRune.Firehose.subscribe(["app.bsky.feed.post"], fn event ->
  # Process event
end)
```

## Implementation Details

### Bot Supervision Strategy

The bot framework will utilize OTP supervision trees:

```
BotSupervisor
├── Bot1
│   ├── EventManager
│   ├── ConnectionManager
│   └── StateManager
├── Bot2
│   ├── EventManager
│   ├── ConnectionManager
│   └── StateManager
└── ...
```

### Event Processing Pipeline

1. Event Source (Firehose/Polling) → Raw Event
2. Event Decoder → Decoded Event
3. Event Filter → Filtered Event
4. Event Handler → Processing Result
5. Result Handler → Side Effects

### State Management

Bots can maintain state using either:
- Process state (GenServer)
- Distributed state (via :pg or similar)
- External storage (configurable)

## Migration Strategy

1. Phase 1: Core XRPC Client
2. Phase 2: Repository Layer
3. Phase 3: Bot Framework (Polling)
4. Phase 4: Firehose Support
5. Phase 5: Advanced Features

## Testing Strategy

- Unit tests for individual components
- Integration tests with mock ATP server
- Property-based testing for protocol operations
- Load testing for firehose consumption

## Security Considerations

- Secure storage of credentials
- Rate limiting compliance
- Content validation
- Safe event handling

## Performance Considerations

- Connection pooling for XRPC clients
- Batched repository operations
- Efficient event filtering
- Memory usage in firehose processing

## Example Configurations

### Minimal Bot

```elixir
defmodule SimpleBot do
  use ProtoRune.Bot,
    strategy: :polling,
    interval: 60_000

  def handle_event(:post, %{author: author, content: content}) do
    if String.contains?(content, "hello") do
      ProtoRune.post("Hello, #{author}!")
    end
  end
end
```

### Firehose Consumer

```elixir
defmodule AnalyticsBot do
  use ProtoRune.Bot,
    strategy: :firehose,
    filters: ["app.bsky.feed.*"],
    buffer_size: 1000,
    workers: 4

  def handle_event(event_type, payload) do
    ProtoRune.Analytics.record(event_type, payload)
  end
end
```

## Future Considerations

1. GraphQL API support
2. Custom lexicon definition support
3. Plugin system
4. Web dashboard integration
5. Multi-node bot coordination

## Timeline

- Month 1: Core XRPC implementation
- Month 2: Repository layer and basic bot framework
- Month 3: Firehose support and advanced features
- Month 4: Testing, documentation, and stability improvements

## Open Questions

1. Should we support both polling and firehose simultaneously?
2. How should we handle schema versioning?
3. What's the best approach for handling large CAR files?
4. How should we implement rate limiting across multiple bots?

## References

1. AT Protocol Specification
2. Bluesky API Documentation
3. JavaScript SDK Implementation
4. Existing proto_rune Implementation
