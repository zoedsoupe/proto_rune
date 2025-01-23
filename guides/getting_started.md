# Getting Started with ProtoRune

## Understanding AT Protocol and ProtoRune

The AT Protocol (Authenticated Transfer Protocol) is a social networking protocol that emphasizes account portability, algorithmic choice, and scalable interoperability. Unlike traditional social platforms where your data and identity are locked to a single provider, AT Protocol allows users to maintain ownership of their identity and move between providers while preserving their social graph and content.

Bluesky is the most well-known application built on AT Protocol, but the protocol itself is designed to support various social applications. ProtoRune provides Elixir developers with tools to build applications, bots, and services that interact with the AT Protocol ecosystem.

### Key Concepts

**Personal Data Servers (PDS)**
A PDS hosts user accounts and their data. Users can choose their PDS provider or self-host. ProtoRune connects to these servers to perform operations on behalf of users.

**Decentralized Identity (DID)**
Users have persistent identifiers called DIDs that remain stable even when changing providers. These DIDs can be resolved to find the current hosting location of an account. ProtoRune handles DID resolution and validation automatically.

**Records and Repositories**
User data in AT Protocol is stored in repositories as typed records (posts, likes, follows, etc.). Each record belongs to a collection and has a specific schema. ProtoRune provides type-safe structs and operations for working with records.

**Lexicons**
AT Protocol uses Lexicons to define schemas and APIs. ProtoRune generates Elixir code from these Lexicons, providing compile-time type checking and documentation.

## Getting Started

### Installation

Add ProtoRune to your dependencies:

```elixir
def deps do
  [
    {:proto_rune, "~> 0.1.0"}
  ]
end
```

### Configuration

Configure your default service in `config/config.exs`:

```elixir
config :proto_rune, 
  default_service: "https://bsky.social",
  http_client: ProtoRune.HTTPClient.Adapters.Finch
```

### Authentication and Sessions

AT Protocol uses sessions for authentication. ProtoRune wraps this in a Session struct:

```elixir
alias ProtoRune.Session

# Create session with handle (recommended for most users)
{:ok, session} = ProtoRune.create_session("handle.bsky.social", "app-password")

# Or with DID (for more advanced use cases)
{:ok, session} = ProtoRune.create_session("did:plc:1234", "app-password")
```

### Working with Records

Records are the core data structures in AT Protocol. Each record type is represented as an Elixir struct with proper typespecs:

```elixir
alias ProtoRune.Bsky.Post
alias ProtoRune.Bsky.Profile

# Create and publish a post
post = Post.new(text: "Hello from ProtoRune!")
{:ok, created} = Post.create(session, post)

# Update a profile
profile = Profile.new(
  display_name: "Zoey",
  description: "Building with ProtoRune"
)
{:ok, updated} = Profile.update(session, profile)
```

### Rich Text Content

AT Protocol supports rich text with mentions, links, and formatting. ProtoRune provides both a pipeline API and a sigil for creating rich text:

```elixir
import ProtoRune.RichText

# Using the sigil for markdown-like syntax
text = ~R"""
Hello @alice.sky! 
Check out this #elixir project at [ProtoRune](https://github.com/proto-rune)
"""

# Or the pipeline API for programmatic construction
text = RichText.new()
  |> RichText.text("Hello ")
  |> RichText.mention("alice.sky")
  |> RichText.text("! Check out this ")
  |> RichText.hashtag("elixir")
  |> RichText.text(" project at ")
  |> RichText.link("ProtoRune", "https://github.com/proto-rune")
```

## Further Reading

- [AT Protocol official documentation](https://atproto.com)
- [AT Protocol Specifications](https://atproto.com/specs/atp)
- [Lexicon Reference](https://atproto.com/specs/lexicon)
