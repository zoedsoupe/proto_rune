# RFC: ProtoRune Elixir SDK for AT Protocol

## Abstract

This RFC proposes a domain-driven implementation of an AT Protocol SDK in Elixir, focusing on developer ergonomics, type safety, and scalable event processing. The implementation leverages Elixir's strengths in metaprogramming, concurrent processing, and functional design while providing clear boundaries between protocol layers.

## Background

AT Protocol enables decentralized social networking through a layered architecture. While existing implementations like `indigo` and `skyware` provide foundational capabilities, an Elixir implementation can uniquely leverage BEAM's strengths for handling concurrent network operations and real-time event processing.

## Goals

- Provide an intuitive, domain-driven API that reflects AT Protocol's layered architecture
- Generate type-safe, validated code from Lexicons with comprehensive documentation
- Enable efficient event processing through multiple strategies
- Maintain extensibility for future AT Protocol features
- Follow Elixir conventions and leverage BEAM capabilities

## Architecture

### Domain Organization

The codebase is organized by domain contexts at the root level, reflecting AT Protocol's layered architecture:

```
lib/
  atproto/     # Core protocol implementation
    xrpc/      # XRPC client and utilities
    repo/      # Repository operations
    identity/  # DID and handle resolution
    sync/      # Data synchronization primitives
    server/    # 

  proto_rune/  # 
    
  lexicon/     # Generated code from Lexicons
    app/
      bsky/    # Bluesky-specific Lexicons
    com/
      atproto/ # Core protocol Lexicons
      
  bluesky/     # Bluesky application features
  ozone/       # Content moderation features
```

### Code Generation

Lexicons are processed at compile-time through a mix task, generating Ecto schemas and type specifications:

```elixir
defmodule Mix.Tasks.Compile.Lexicon do
  use Mix.Task
  
  @impl Mix.Task
  def run(_args) do
    # Process lexicon JSON files
    # Generate Elixir modules with proper namespacing
  end
end
```

The generated code provides validation and documentation while maintaining clear mapping to AT Protocol data structures:

```elixir
# Abrevviated fields just for clarity and example purposes
defmodule Lexicon.App.Bsky.Feed.Post do
  @moduledoc "Record containing a Bluesky post."

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc """
  - `text`: The primary post content. May be an empty string, if there are embeds.
  - `created_at`: Client-declared timestamp when this post was originally created.
  - `facets`: Annotations of text (mentions, URLs, hashtags, etc)
  """
  @type t :: %__MODULE__{
    text: String.t,
    created_at: DateTime.t,
    facets: list(Facet.t),
  }
  
  @primary_key false
  embedded_schema do
    field :text, :string
    field :created_at, :utc_datetime
    
    embeds_many :facets, Facet
    embeds_one :embed, Embed
  end
  
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:text, :created_at])
    |> validate_required([:text, :created_at])
    |> validate_length(:text, max: 300)
  end
end
```

### Error Handling

A unified error system categorizes and handles different types of failures:

```elixir
defmodule ATProto.Error do
  defexception [:type, :message, :reason]
  
  def transient(:rate_limit), do: %__MODULE__{
    type: :transient,
    message: "Rate limited",
    reason: :rate_limit
  }
  
  def permanent(:auth), do: %__MODULE__{
    type: :permanent,
    message: "Authentication failed",
    reason: :auth
  }
end
```

### Event Processing

The system supports multiple event processing strategies through a composable architecture:

```elixir
defmodule ATProto.EventSource.Polling do
  use GenServer
  
  def init(config) do
    schedule_poll()
    {:ok, %{interval: config.interval}}
  end
  
  defp schedule_poll do
    Process.send_after(self(), :poll, @interval)
  end
end

defmodule ATProto.EventSource.Firehose do
  use GenServer
  
  def init(config) do
    {:ok, socket} = connect_websocket(config)
    {:ok, %{socket: socket}}
  end
end
```

Bots can use any event source through a unified interface:

```elixir
defmodule MyBot do
  use ATProto.Bot,
    name: :my_bot,
    source: :firehose  # or :polling
    
  def handle_event(:like, payload) do
    # Handle like event
  end
end
```

### Supervision and Monitoring

Each bot runs under its own supervisor tree:

```elixir
defmodule ATProto.Bot.Supervisor do
  use Supervisor
  
  def init({bot_module, init_args}) do
    children = [
      {bot_module, init_args},
      {ATProto.EventSource.Polling, init_args}
    ]
    
    Supervisor.init(children, strategy: :one_for_all)
  end
end
```

Telemetry integration provides observability:

```elixir
:telemetry.span(
  [:proto_rune, :polling],
  %{bot: state.bot_name},
  fn ->
    result = fetch_notifications(state)
    {result, %{duration: System.monotonic_time() - start_time}}
  end
)
```

## Public API and Builder Patterns

### Rich Content Construction

One of the most common tasks when working with AT Protocol is constructing rich text content with mentions, links, and formatting. We provide two complementary approaches: a pipeline-based builder pattern and a custom sigil.

The builder pattern leverages Elixir's pipe operator for readable, chainable operations:

```elixir
defmodule ATProto.RichText do
  @moduledoc """
  Provides a fluent API for constructing rich text content.
  
  The builder pattern maintains immutability while allowing
  natural composition of text elements.
  """
  
  defstruct text: "", facets: []
  
  def new(initial_text \\ "") do
    %__MODULE__{text: initial_text}
  end
  
  def text(builder, content) do
    %{builder | text: builder.text <> content}
  end
  
  def mention(builder, handle) do
    # Calculate byte indices for the mention
    start = String.length(builder.text)
    builder = text(builder, "@#{handle}")
    
    facet = %{
      index: %{
        byteStart: start,
        byteEnd: start + byte_size(handle) + 1
      },
      features: [%{$type: "app.bsky.richtext.facet#mention", did: handle}]
    }
    
    %{builder | facets: [facet | builder.facets]}
  end
  
  # Similar implementations for links, hashtags, etc.
end
```

This can be used like:

```elixir
# Building rich text through method chaining
post = ATProto.RichText.new()
  |> ATProto.RichText.text("Hello ")
  |> ATProto.RichText.mention("alice.bsky.social")
  |> ATProto.RichText.text("! Check out ")
  |> ATProto.RichText.link("our project", "https://example.com")
  |> ATProto.RichText.hashtag("elixir")
```

For more extensive and complex use cases, we provide a custom sigil that offers a more concise syntax:

```elixir
defmodule ATProto.Sigils do
  @doc """
  Provides a markdown-like syntax for rich text construction.
  
  Supports:
  - @mentions
  - #hashtags
  - [links](url)
  """
  def sigil_f(text, _opts) do
    # Parse the text and construct rich text with proper facets
    ATProto.RichText.Parser.parse(text)
  end
end

# Using the sigil
import ATProto.Sigils

# parses the rich text on compile time ^-^
post = ~f"""
Hello @alice.bsky.social!
Check out [our project](https://example.com) #elixir
"""
```

### Post Creation and Interaction

The public API provides high-level functions for common operations while maintaining access to lower-level primitives:

```elixir
defmodule ATProto.Bluesky do
  @moduledoc """
  High-level API for Bluesky-specific operations.
  
  This module provides ergonomic functions for common tasks while
  internally managing the complexities of AT Protocol interactions.
  """
  
  @type post_opts :: [
    reply_to: String.t(),
    langs: [String.t()],
    labels: [String.t()],
    # Other options...
  ]
  
  @doc """
  Creates a new post with rich text content.
  
  ## Examples
  
      # Simple text post
      ATProto.Bluesky.post(session, "Hello world!")
      
      # Rich text with builder pattern
      post_content = ATProto.RichText.new()
        |> ATProto.RichText.text("Hello ")
        |> ATProto.RichText.mention("alice.bsky.social")
      
      ATProto.Bluesky.post(session, post_content)
      
      # Reply to another post
      ATProto.Bluesky.post(session, "Great point!",
        reply_to: "at://did:plc:1234/app.bsky.feed.post/123")
  """
  @spec post(Session.t(), String.t() | RichText.t(), post_opts()) ::
    {:ok, Post.t()} | {:error, Error.t()}
  def post(session, content, opts \\ []) do
    # Convert content to proper format
    # Handle reply threading if reply_to is present
    # Create post record
    # Upload any embedded media
    # Publish through XRPC
  end
  
  @doc """
  Retrieves a thread of posts, handling pagination and
  parent/child relationships.
  """
  @spec get_thread(Session.t(), String.t(), keyword()) ::
    {:ok, Thread.t()} | {:error, Error.t()}
  def get_thread(session, uri, opts \\ []) do
    # Fetch thread with proper depth
    # Organize posts into thread structure
    # Handle deleted/moderated content
  end
end
```

### Repository Operations 

For developers needing lower-level access, we expose the core repository operations while maintaining safety and proper error handling:

```elixir
defmodule ATProto.Repo do
  @moduledoc """
  Provides direct access to AT Protocol repository operations.
  
  These functions implement the foundational CRUD operations
  defined by AT Protocol, with proper handling of CIDs, commits,
  and Merkle tree validation.
  """
  
  @doc """
  Creates a record in a repository with proper validation
  and Merkle tree updates.
  """
  @spec create_record(Session.t(), String.t(), term(), keyword()) ::
    {:ok, Record.t()} | {:error, Error.t()}
  def create_record(session, collection, record, opts \\ []) do
    with {:ok, validated} <- validate_record(collection, record),
         {:ok, cid} <- compute_cid(validated),
         {:ok, _} <- update_merkle_tree(session, cid, validated) do
      # Commit changes
    end
  end
  
  @doc """
  Efficiently computes differences between two repository
  states using Merkle Search Trees.
  """
  @spec diff(repo_a :: String.t(), repo_b :: String.t()) ::
    {:ok, [Record.t()]} | {:error, Error.t()}
  def diff(repo_a, repo_b) do
    # Use MST to identify different blocks
    # Fetch only necessary records
    # Return structured diff
  end
end
```

### Understanding Merkle Search Trees

The Merkle Search Tree implementation deserves special attention as it's fundamental to efficient repository synchronization. Here's a detailed look at its implementation:

```elixir
defmodule ATProto.MST do
  @moduledoc """
  Implements Merkle Search Trees for efficient repository
  comparison and synchronization.
  
  MSTs combine the properties of:
  - B-trees for efficient range queries
  - Merkle trees for content verification
  - Search trees for ordered key spaces
  """
  
  # Implementation details...
  
  @doc """
  Determines which blocks need to be synchronized between
  two MSTs by comparing their structure.
  
  This is more efficient than comparing entire repositories
  as it only needs to traverse branches that differ.
  """
  def sync_blocks(local_root, remote_root) do
    # Compare root hashes
    # Traverse only differing branches
    # Return minimal set of blocks needed
  end
end
```

### Why These Design Choices?

1. **Builder Pattern**: We chose a builder pattern for rich text because it:
   - Maintains immutability while being composable
   - Provides clear, chainable operations
   - Makes complex content construction readable
   - Allows for extension with new content types

2. **Custom Sigil**: The `~f` sigil complements the builder pattern by:
   - Offering a concise syntax for simple cases
   - Supporting familiar markdown-like formatting
   - Making code more readable for text-heavy content

3. **Layered API**: The API is structured in layers because:
   - High-level functions handle common use cases simply
   - Lower-level access enables advanced usage
   - Domain separation maintains clear boundaries
   - Each layer can evolve independently

## Implementation Phases

1. Core Protocol Layer (ATProto)
   - XRPC client implementation
   - Repository operations
   - Identity resolution
   - Basic synchronization

2. Code Generation
   - Lexicon parsing and IR
   - Ecto schema generation
   - Type specification generation
   - Documentation generation

3. Event Processing
   - Polling implementation
   - Firehose implementation
   - Bot supervision
   - Error handling

4. Application Layer
   - Bluesky integration
   - Jetstream support
   - Ozone integration

## Future Considerations

- Advanced event filtering and transformation
- Custom Lexicon support
- Integration with other AT Protocol applications (white-wind, ozone, teal, ...)

## Security Considerations

- Rate limiting and backoff strategies
- Secure credential management
- Input validation and sanitization
- Network timeout handling
- Resource usage monitoring

The implementation must follow AT Protocol security guidelines and implement proper error handling for all network operations.

## Conclusion

This architecture provides a solid foundation for building AT Protocol applications in Elixir while maintaining extensibility for future protocol developments. The domain-driven organization will help developers build reliable applications while leveraging BEAM's strengths.

The proposed implementation balances developer ergonomics with protocol compliance, providing both high-level abstractions for common use cases and low-level access for advanced scenarios.
