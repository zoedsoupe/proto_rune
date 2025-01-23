# Understanding XRPC and Low-Level API Usage

## What is XRPC?

XRPC (Cross-server Remote Procedure Call) is AT Protocol's approach to HTTP APIs. While it follows RESTful principles, XRPC adds some protocol-specific features:

- **Lexicon-defined endpoints**: Each endpoint is defined by a Lexicon schema
- **Strongly-typed parameters**: Input and output are validated against schemas
- **Namespaced methods**: Endpoints follow a hierarchical naming (e.g., `com.atproto.repo.createRecord`)
- **Session-based auth**: Uses JWT tokens for authentication
- **Consistent error handling**: Standardized error responses across services

## XRPC in ProtoRune

While ProtoRune provides high-level abstractions like `ProtoRune.create_session/2`, understanding the XRPC layer helps when:
- Building custom features
- Working with new Lexicons
- Debugging issues
- Implementing advanced functionality

Here's how the layers connect:

```elixir
{:ok, session} = ProtoRune.create_session("identifier", "password")

# High-level API (recommended for most uses)
{:ok, post} = ProtoRune.ATProto.create_record(text: "Hello world!")

# Is equivalent to:
ProtoRune.XRPC.procedure(session,
  "com.atproto.repo.createRecord",
  %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    record: %{text: "Hello world!"}
  }
)
```

## Using XRPC Directly

### Queries (GET Requests)

```elixir
# Get a profile
{:ok, profile} = ProtoRune.XRPC.query(session,
  "app.bsky.actor.getProfile",
  %{actor: "alice.bsky.social"}
)

# List records with parameters
{:ok, posts} = ProtoRune.XRPC.query(session,
  "app.bsky.feed.getAuthorFeed",
  %{
    actor: "bob.bsky.social",
    limit: 50,
    filter: "posts_with_media"
  }
)
```

### Procedures (POST Requests)

```elixir
# Create a record
{:ok, record} = ProtoRune.XRPC.procedure(session,
  "com.atproto.repo.createRecord",
  %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    record: %{
      text: "Hello via XRPC!",
      createdAt: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  }
)

# Delete a record
{:ok, _} = ProtoRune.XRPC.procedure(session,
  "com.atproto.repo.deleteRecord",
  %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    rkey: "1234"
  }
)
```

### Error Handling

XRPC provides structured errors:

```elixir
case ProtoRune.XRPC.query(session, "app.bsky.feed.getPost", %{uri: invalid_uri}) do
  {:ok, post} -> 
    # Handle success
  
  {:error, %ProtoRune.XRPC.Error{
    code: :not_found,
    message: "Post not found"
  }} ->
    # Handle specific error
    
  {:error, %ProtoRune.XRPC.Error{code: :rate_limit}} ->
    # Handle rate limiting
end
```

## Working with Lexicons

XRPC endpoints are defined by Lexicons. ProtoRune generates code from these definitions:

```elixir
# Generated module for an XRPC method
defmodule ProtoRune.Lexicons.ATProto.Repo.CreateRecord do
  @type params :: %{
    repo: String.t(),
    collection: String.t(),
    rkey: String.t() | nil,
    validate: boolean() | nil,
    record: map()
  }

  @type response :: %{
    uri: String.t(),
    cid: String.t()
  }
  
  def path, do: "com.atproto.repo.createRecord"
  def method, do: :post
end
```

## Custom XRPC Methods

For methods not covered by ProtoRune's high-level API:

```elixir
# Define your method
defmodule MyApp.CustomMethod do
  use ProtoRune.XRPC.Method,
    path: "com.example.customMethod",
    method: :post

  @type params :: %{
    customField: String.t()
  }
  
  @type response :: %{
    result: String.t()
  }
end

# Use it
ProtoRune.XRPC.call(session, MyApp.CustomMethod, %{
  customField: "value"
})
```

## Advanced Usage

### Raw Requests

Access the underlying HTTP client:

```elixir
# Direct HTTP request
ProtoRune.XRPC.request(session,
  method: :post,
  path: "com.atproto.repo.createRecord",
  body: data,
  headers: [{"Content-Type", "application/json"}]
)
```

### Custom Response Handling

Process raw responses:

```elixir
case ProtoRune.XRPC.raw_query(session, "app.bsky.feed.getTimeline") do
  {:ok, %{status: 200, body: body}} ->
    # Handle raw response
    
  {:ok, %{status: status}} when status in 400..499 ->
    # Handle client error
    
  {:error, _reason} ->
    # Handle network error
end
```

## Best Practices

1. **Use High-Level APIs First**: Only drop to XRPC when needed
2. **Handle Rate Limits**: Implement exponential backoff
3. **Validate Input**: Check params match Lexicon schemas
4. **Type Everything**: Use typespecs for custom methods

## Further Reading

- [AT Protocol XRPC Spec](https://atproto.com/specs/xrpc)
- [Lexicon Reference](https://atproto.com/specs/lexicon)
- [XPRC HTTP Status Codes](https://atproto.com/specs/xrpc#summary-of-http-status-codes)
