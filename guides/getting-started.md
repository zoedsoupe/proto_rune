# Getting Started

## Installation

```elixir
def deps do
  [
    {:proto_rune, "~> 0.5.3"}
  ]
end
```

```bash
mix deps.get
```

## Your first post

Grab an [app password](https://bsky.app/settings/app-passwords) (never use your main password), then:

```elixir
{:ok, session} = ProtoRune.login("you.bsky.social", "your-app-password")
{:ok, post} = ProtoRune.Bsky.post(session, "Hello from Elixir!")
```

## Sessions

A session holds your tokens and account info. Every API call takes it as the first argument, there is no global state.

```elixir
# Session contains:
# - access_jwt: short-lived access token
# - refresh_jwt: long-lived refresh token
# - did, handle, service_url

# Access tokens expire, refresh when needed:
{:ok, fresh_session} = ProtoRune.refresh_session(session)
```

## Common operations

```elixir
# Social
{:ok, like} = ProtoRune.Bsky.like(session, post.uri, post.cid)
{:ok, repost} = ProtoRune.Bsky.repost(session, post.uri, post.cid)
{:ok, follow} = ProtoRune.Bsky.follow(session, "alice.bsky.social")

# Reading
{:ok, timeline} = ProtoRune.Bsky.get_timeline(session, limit: 20)
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "bob.bsky.social")
{:ok, thread} = ProtoRune.Bsky.get_post_thread(session, post_uri)

# Identity
{:ok, did} = ProtoRune.resolve_handle("alice.bsky.social")
{:ok, doc} = ProtoRune.resolve_did("did:plc:abc123xyz")
```

## Error handling

Everything returns tagged tuples:

```elixir
case ProtoRune.login(identifier, password) do
  {:ok, session} -> ProtoRune.Bsky.post(session, "Success!")
  {:error, reason} -> IO.puts("Login failed: #{inspect(reason)}")
end
```

## Next steps

- [Authentication](authentication.md): app passwords, OAuth, token storage
- [Posting content](posting-content.md): rich text, replies, language tags
- [Bot development](bot-development.md): event-driven bots on OTP
- [Repository operations](repository-operations.md): low-level record CRUD
