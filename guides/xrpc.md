# XRPC and Low-Level API

XRPC is AT Protocol's HTTP API layer: lexicon-defined endpoints, schema-validated input/output, namespaced methods like `com.atproto.repo.createRecord`, JWT auth, standardized errors.

ProtoRune's high-level API sits on top of it:

```elixir
{:ok, post} = ProtoRune.Bsky.post(session, "Hello world!")

# is equivalent to:
ProtoRune.XRPC.procedure(session, "com.atproto.repo.createRecord", %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  record: %{text: "Hello world!"}
})
```

Drop to the XRPC layer for endpoints the high-level API doesn't cover yet, or for debugging.

## Queries (GET)

```elixir
{:ok, profile} =
  ProtoRune.XRPC.query(session, "app.bsky.actor.getProfile", %{
    actor: "alice.bsky.social"
  })

{:ok, posts} =
  ProtoRune.XRPC.query(session, "app.bsky.feed.getAuthorFeed", %{
    actor: "bob.bsky.social",
    limit: 50,
    filter: "posts_with_media"
  })
```

## Procedures (POST)

```elixir
{:ok, record} =
  ProtoRune.XRPC.procedure(session, "com.atproto.repo.createRecord", %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    record: %{
      text: "Hello via XRPC!",
      createdAt: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  })
```

## Errors

```elixir
case ProtoRune.XRPC.query(session, "app.bsky.feed.getPost", %{uri: uri}) do
  {:ok, post} -> post
  {:error, %ProtoRune.XRPC.Error{code: :not_found}} -> # gone
  {:error, %ProtoRune.XRPC.Error{code: :rate_limit}} -> # back off
end
```

## Custom methods

For endpoints with no generated module:

```elixir
defmodule MyApp.CustomMethod do
  use ProtoRune.XRPC.Method,
    path: "com.example.customMethod",
    method: :post

  @type params :: %{customField: String.t()}
  @type response :: %{result: String.t()}
end

ProtoRune.XRPC.call(session, MyApp.CustomMethod, %{customField: "value"})
```

## Raw requests

When you need full control over the HTTP call:

```elixir
ProtoRune.XRPC.request(session,
  method: :post,
  path: "com.atproto.repo.createRecord",
  body: data,
  headers: [{"Content-Type", "application/json"}]
)
```

## Further reading

- [AT Protocol XRPC spec](https://atproto.com/specs/xrpc)
- [Lexicon reference](https://atproto.com/specs/lexicon)
