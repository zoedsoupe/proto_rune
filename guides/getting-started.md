# Getting Started with ProtoRune

ProtoRune is an Elixir SDK for the AT Protocol, providing type-safe interfaces for building Bluesky applications and bots.

## Installation

Add ProtoRune to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:proto_rune, "~> 0.2.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Your First Post

The quickest way to get started is to create a session and post content:

```elixir
# Start your application
iex -S mix

# Login to create a session
{:ok, session} = ProtoRune.login(
  "your-handle.bsky.social",
  "your-app-password"
)

# Post something
{:ok, post} = ProtoRune.Bsky.post(session, "Hello from Elixir and ProtoRune!")
```

## Understanding Sessions

A session contains authentication tokens and your account information. Sessions are created through login and can be refreshed when tokens expire:

```elixir
# Create session
{:ok, session} = ProtoRune.login(identifier, password)

# Session contains:
# - access_jwt: Short-lived access token
# - refresh_jwt: Long-lived refresh token
# - did: Your decentralized identifier
# - handle: Your handle
# - service_url: Your PDS endpoint

# Refresh when access token expires
{:ok, fresh_session} = ProtoRune.refresh_session(session)
```

## Basic Operations

Once you have a session, you can perform various operations:

### Social Interactions

```elixir
# Like a post
{:ok, like} = ProtoRune.Bsky.like(session, post.uri, post.cid)

# Repost
{:ok, repost} = ProtoRune.Bsky.repost(session, post.uri, post.cid)

# Follow someone
{:ok, follow} = ProtoRune.Bsky.follow(session, "alice.bsky.social")
```

### Reading Content

```elixir
# Get your timeline
{:ok, timeline} = ProtoRune.Bsky.get_timeline(session, limit: 20)

# Get someone's profile
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "bob.bsky.social")

# Get a post thread
{:ok, thread} = ProtoRune.Bsky.get_post_thread(session, post_uri)
```

## Identity Resolution

ProtoRune provides utilities for working with DIDs and handles:

```elixir
# Resolve a handle to a DID
{:ok, did} = ProtoRune.resolve_handle("alice.bsky.social")
# => {:ok, "did:plc:abc123xyz"}

# Resolve a DID to its document
{:ok, doc} = ProtoRune.resolve_did("did:plc:abc123xyz")

# Validate identity binding
{:ok, doc} = ProtoRune.validate_identity("alice.bsky.social")
```

## Error Handling

All ProtoRune functions return tagged tuples for explicit error handling:

```elixir
case ProtoRune.login(identifier, password) do
  {:ok, session} ->
    # Proceed with session
    {:ok, post} = ProtoRune.Bsky.post(session, "Success!")

  {:error, reason} ->
    # Handle authentication failure
    IO.puts("Login failed: #{inspect(reason)}")
end
```

## Next Steps

- Learn about [authentication strategies](authentication.md)
- Explore [posting content and rich text](posting-content.md)
- Build [bots with the bot framework](bot-development.md)
- Understand [repository operations](repository-operations.md) for advanced use cases
- Review [error handling patterns](error-handling.md)

## Configuration

You can configure ProtoRune in your `config/config.exs`:

```elixir
config :proto_rune,
  base_url: "https://bsky.social/xrpc"
```

This sets the default service URL for API calls. You can override this per-session by passing the `:service` option to `login/3`.
