# XRPC and Low-Level API

XRPC is AT Protocol's HTTP API layer: lexicon-defined endpoints, schema-validated input/output, namespaced methods like `com.atproto.repo.createRecord`, JWT auth, standardized errors.

ProtoRune's high-level API sits on top of it. The generated `ProtoRune.Bsky.*` and `ProtoRune.Atproto.*` endpoint modules cover the published lexicons; drop to the XRPC layer for endpoints with no generated module, or for debugging.

## Generated endpoints

Every lexicon endpoint is a function defined with the `ProtoRune.XRPC.DSL` macros:

```elixir
{:ok, profile} =
  ProtoRune.Bsky.Actor.get_profile(session, %{actor: "alice.bsky.social"})

{:ok, posts} =
  ProtoRune.Bsky.Feed.get_author_feed(session, %{
    actor: "bob.bsky.social",
    limit: 50,
    filter: "posts_with_media"
  })
```

Authenticated endpoints take the session first; public ones take only the params map. Params are validated against the endpoint's schema before any request is made.

## Defining your own endpoints

Use `defquery` (GET) and `defprocedure` (POST) from `ProtoRune.XRPC.DSL`:

```elixir
defmodule MyApp.Bsky do
  import ProtoRune.XRPC.DSL

  defquery "app.bsky.actor.getProfile", authenticated: :optional do
    param :actor, {:required, :string}
  end

  defprocedure "com.example.customMethod", authenticated: true do
    param :custom_field, {:required, :string}
  end
end
```

The function name is the snakelized last segment of the method (`getProfile` → `get_profile/2`). With `authenticated: true` the function takes `(session, params)`; with `authenticated: :optional` both `(session, params)` and `(params)` clauses exist; the default is a public `(params)`-only function.

## Manual requests

For full control, build the request structs by hand and execute them with `ProtoRune.XRPC.Client`:

```elixir
alias ProtoRune.XRPC.Client
alias ProtoRune.XRPC.Procedure
alias ProtoRune.XRPC.Query

{:ok, profile} =
  "app.bsky.actor.getProfile"
  |> Query.new()
  |> Query.put_param(:actor, "alice.bsky.social")
  |> Client.execute()

{:ok, record} =
  "com.atproto.repo.createRecord"
  |> Procedure.new(base_url: ProtoRune.Session.service_url(session))
  |> Procedure.put_body(%{repo: repo, collection: collection, record: record})
  |> Client.execute()
```

To authenticate a manual request, merge the headers from the session behaviour:

```elixir
{:ok, headers, session} = ProtoRune.Session.authorization_headers(session, "POST", url)
```

This is what the generated functions do; it handles both `Bearer` (app password) and DPoP (OAuth) sessions.

## Errors

Failures return `%ProtoRune.XRPC.Error{}`:

```elixir
alias ProtoRune.XRPC.Error

case ProtoRune.Bsky.Feed.get_post_thread(session, %{uri: uri}) do
  {:ok, thread} -> thread
  {:error, %Error{reason: :not_found}} -> # gone
  {:error, %Error{reason: :rate_limited, retry_after: retry}} -> # back off
end
```

`reason` is the lexicon error name snakelized (`"RecordNotFound"` → `:record_not_found`), or a generic atom from the HTTP status when the body carries no error name. `message` holds the server's human-readable message, `http_status` the status code.

## Further reading

- [AT Protocol XRPC spec](https://atproto.com/specs/xrpc)
- [Lexicon reference](https://atproto.com/specs/lexicon)
