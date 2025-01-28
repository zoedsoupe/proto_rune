## Introduction

In AT Protocol, identities work similarly to email addresses and DNS - users have human-readable handles (like `alice.bsky.social`) that map to permanent identifiers called DIDs. This guide will show you how to work with identities using `ProtoRune`.

## Basic Identity Resolution

The most common operation is resolving a handle to get account details:

```elixir
alias ATProto.Identity

# Simple handle to DID resolution
case Identity.resolve_handle("alice.bsky.social") do
  {:ok, did} ->
    # Got the DID like "did:plc:1234..."

  {:error, :not_found} ->
    # Handle doesn't exist

  {:error, :network_error} ->
    # Temporary failure, can retry
end

# Get full account details including service endpoint
case Identity.validate_identity("alice.bsky.social") do
  {:ok, doc} ->
    # Access identity details:
    IO.puts "DID: #{doc.id}"
    IO.puts "PDS URL: #{doc.service_endpoint}"
    IO.puts "Current handle: #{doc.handle}"

  {:error, reason} ->
    IO.puts "Identity validation failed: #{reason}"
end
```

## Working with DIDs Directly

You can also work with DIDs directly when you need lower-level control:

```elixir
alias ATProto.Identity

# Resolve just the DID document
case Identity.resolve_did("did:plc:1234...") do
  {:ok, doc} ->
    # Full DID document with keys, services etc.

  {:error, :unsupported_did_method} ->
    # Only did:plc and did:web are supported
end

# Verify a signature using the DID's key
case Identity.verify_signature(did, message, signature) do
  :ok ->
    # Signature is valid

  {:error, :invalid_signature} ->
    # Signature doesn't match
end
```

## Creating Sessions

When authenticating as a user, ProtoRune handles the identity verification:

```elixir
# Create session with handle
{:ok, session} = ATProto.create_session(
  identifier: "mybot.bsky.social",
  password: "app-password"
)

# Create session with DID
{:ok, session} = ATProto.create_session(
  identifier: "did:plc:1234...",
  password: "app-password"
)

# Session contains verified identity info
IO.puts "Logged in as #{session.did}"
IO.puts "Using PDS at #{session.service_endpoint}"
```

## Managing Identity in Bots

When building bots, `ProtoRune` handles identity management automatically:

```elixir
defmodule MyBot do
  use ProtoRune.Bot

  @impl true
  def get_identifier do
    # Return your bot's handle or DID
    System.fetch_env!("BOT_IDENTIFIER")
  end

  def get_password do
    System.fetch_env!("BOT_PASSWORD")
  end

  # ProtoRune maintains the session and handles
  # identity verification for all operations
  @impl true
  def handle_event(:follow, payload) do
    # payload.user.did is already verified
    # payload.user.handle is verified to match the DID
  end
end
```

## Caching and Performance

ProtoRune handles caching of identity resolution automatically:

```elixir
# Configure cache settings
config :proto_rune, ATProto.Identity.Cache,
  # How long to cache DID documents
  did_ttl: :timer.hours(24),

  # How long to cache handle->DID mappings
  handle_ttl: :timer.hours(1),

  # Maximum cache size
  max_size: 10_000

# Force refresh cache for a handle
ATProto.Identity.refresh_handle("alice.bsky.social")

# Force refresh DID document
ATProto.Identity.refresh_did("did:plc:1234...")
```

## Security Considerations

- Always verify bi-directional handle-DID resolution
- Don't trust unverified DIDs or handles
- Cache but respect TTLs to handle rotated keys
- Handle rate limits appropriately
- Consider timeouts for network operations

## Common Patterns

Here are some common patterns when working with identities:

```elixir
import ATProto.Identity, only: [is_handle: 1, is_did: 1]
alias ATProto.Identity

# Pattern match on handle or DID
def process_identifier(identifier) when is_did(identifier) do
  process_did(identifier)
end

def process_identifier(identifier) when is_handle(identifier) do
  process_handle(identifier)
end

def process_identifier(_), do: {:error, :invalid_identifier}

# Batch resolve identities
def resolve_many(identifiers) do
  # ProtoRune handles concurrent resolution
  Task.async_stream(identifiers, &Identity.resolve_handle/1)
  |> Enum.into(%{})
end
```

## Testing

You can easily mock identity resolution for testing with `mox`:

```elixir
# In test helper
ExUnit.start()
Mox.defmock(ATProto.Identity.Mock, for: ATProto.Identity.Behaviour)

# In your test
test "resolves handle" do
  ATProto.Identity.Mock
  |> expect(:resolve_handle, fn "test.bsky.social" -> {:ok, "did:plc:test"} end)

  assert {:ok, "did:plc:test"} == ATProto.Identity.resolve_handle("test.bsky.social")
end
```

Remember that identity management is a core part of AT Protocol security. `ProtoRune` handles the complexities of resolution, verification and caching, while providing clear APIs for working with identities in your application.
