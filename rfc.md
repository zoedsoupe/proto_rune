# RFC: ProtoRune v0.1.0 - AT Protocol SDK for Elixir

## Abstract

This RFC proposes a comprehensive Elixir SDK implementation for the AT Protocol. The implementation aims to provide both a high-level developer-friendly API for common use cases while exposing low-level primitives for advanced usage. The design leverages Elixir's strengths in code generation and functional programming.

## Status

Draft

## Background

AT Protocol uses Lexicons to define schemas, APIs, and record types. Current SDK implementations like go-atproto and atproto-js generate code from these lexicons to provide type-safe interfaces. This proposal aims to provide a similar capability while embracing Elixir idioms and the BEAM ecosystem.

## Goals

- Provide an intuitive high-level API for common AT Protocol operations
- Generate "parse, don't validate" code from Lexicons
- Leverage Elixir's pipe operator and builder patterns
- Support client apps
- Enable easy bot development
- Maintain extensibility for future AT Protocol features
- Follow Elixir best practices and conventions

## Architecture Overview

### Core Components

1. **Public API Module (`ProtoRune`)**
   - Session management and authentication
   - High-level record operations
   - Social actions (post, like, follow)
   - Rich text construction
   - Bot creation and management

```elixir
# High-level API examples
defmodule ProtoRune do
  def create_session(identifier, password, opts \\ [])
  def publish_post(session, params_or_builder, opts \\ []) 
  def upload_blob(session, binary, opts \\ [])
  def follow(session, target, opts \\ [])
end
```

2. **Core Protocol Layer (`ProtoRune.ATProto`)**
   - Repository operations
   - Identity resolution
   - Record manipulation
   - CBOR/CAR encoding
   - DID operations

```elixir
defmodule ProtoRune.ATProto.Repo do
  def create_record(session, collection, record, opts \\ [])
  def get_record(session, collection, rkey, opts \\ [])
  def list_records(session, collection, opts \\ [])
end

defmodule ProtoRune.ATProto.Identity do
  def resolve_handle(handle)
  def resolve_did(did)
end
```

3. **App-Specific Layers (`ProtoRune.Bsky`, `ProtoRune.Ozone`)**
   - App-specific record builders
   - Feed algorithms
   - Specialized queries
   - Custom procedures

```elixir
defmodule ProtoRune.Bsky.Post do
  def new do
    %Post{}
  end
  
  def with_text(post, text)
  def with_image(post, image, alt)
  def with_link(post, url, title \\ nil)
end
```

4. **Generated Code (`ProtoRune.Lexicons`)**
   - Record schemas and typespecs
   - Query/procedure interfaces
   - Validation logic

```elixir
# Generated from Lexicons
defmodule ProtoRune.Lexicon.App.Bsky.Feed.Post do
  use Ecto.Schema
  
  @primary_key false
  embedded_schema do
    field :text, :string
    field :created_at, :utc_datetime
    embeds_many :facets, Facet
    embeds_one :embed, Embed
  end
  
  @type t :: %__MODULE__{
    text: String.t(),
    created_at: DateTime.t(),
    facets: [Facet.t()],
    embed: Embed.t() | nil
  }
end
```

5. **Bot Framework (`ProtoRune.Bot`)**
   - Event handling
   - State management 
   - Polling strategy
   - Error recovery

```elixir
defmodule ProtoRune.Bot do
  @callback handle_event(event :: Event.t(), state :: term) ::
    {:ok, new_state} | {:error, reason}
    
  @callback get_identifier() :: String.t()
  @callback get_password() :: String.t()
end
```

6. **XRPC Client (`ProtoRune.XRPC`)**
   - HTTP request handling
   - Authentication
   - Error mapping
   - Rate limiting

### Code Generation

The code generator will produce:

1. **Record Schemas**
   - Ecto schemas for validation
   - Typespecs for static analysis

2. **Query/Procedure Modules**
   - Ecto schemaless changesets parameters
   - Response structs
   - Error handling

3. **Helper Functions**  
   - Record creation
   - Validation
   - Format conversion

```elixir
# Example generated code structure
defmodule ProtoRune.Lexicon do
  # Shared types across lexicons
  
  defmodule App.Bsky.Feed.Post do
    # Record schema and types
  end
  
  defmodule Com.ATProto.Repo.CreateRecord do
    # Procedure definition
  end
end
```

## Implementation Details

### Record Building

Records should use a builder pattern that leverages pipes:

```elixir
alias ProtoRune.Bsky.Post

Post.new()
|> Post.with_text("Check out my new project!")
|> Post.with_image("cat.jpg", "A cute cat")
|> Post.with_link("https://example.com")
|> then(&ProtoRune.publish_post(session, &1))
```

### Rich Text Construction

Support both pipeline and sigil syntax:

```elixir
# Pipeline
RichText.new()
|> RichText.text("Hello ")
|> RichText.mention("alice.sky")

# Sigil
~f"""
Hello @alice.sky! 
Check out my [new project](https://example.com)!
"""
```

### Generated Code Usage

Generated code provides type safety while remaining ergonomic:

```elixir
alias ProtoRune.Lexicon.App.Bsky.Feed.Post

# Builder pattern, easier for embeds/facets
Post.new()
|> Post.with_text("Hello!")
|> then(&ProtoRune.publish_post(session, &1))

# directly passing parameters
ProtoRune.publish_post(session, text: "Hello!")
```

## Future Considerations 

1. Firehose support
2. Jetstream support
3. Custom lexicon compilation
4. Federation tooling
5. Multi-node coordination
6. Web dashboard integration

## Timeline

- Month 1: Core XRPC and record handling
- Month 2: Code generation and high-level API
- Month 3: Bot framework and rich text
- Month 4: Documentation and stability 

## References

1. AT Protocol Specification
2. Lexicon Documentation
3. Existing SDKs (python, go, skyware, ...)
