# Repository Operations

Low-level record CRUD in `ProtoRune.Atproto.Repo`. Most apps should use the `ProtoRune.Bsky` helpers instead; drop to this layer for custom record types, concurrency control or non-standard collections.

A record has a **collection** (e.g. `"app.bsky.feed.post"`), an **rkey** (unique within the collection) and the record data itself.

## CRUD

```elixir
alias ProtoRune.Atproto.Repo

# Create
{:ok, %{uri: uri, cid: cid}} =
  Repo.create_record(session, %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    record: %{
      "$type" => "app.bsky.feed.post",
      "text" => "Hello from low-level API",
      "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  })

# Read (:cid optional, fetches a specific version)
{:ok, record} =
  Repo.get_record(session, %{
    repo: "did:plc:abc123",
    collection: "app.bsky.feed.post",
    rkey: "3kxyz..."
  })

# Update
{:ok, result} =
  Repo.put_record(session, %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    rkey: "3kxyz...",
    record: updated_record
  })

# Delete
{:ok, result} =
  Repo.delete_record(session, %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    rkey: "3kxyz..."
  })

# List (paginated)
{:ok, %{records: records, cursor: cursor}} =
  Repo.list_records(session, %{
    repo: session.did,
    collection: "app.bsky.feed.post",
    limit: 50
  })
```

`put_record` and `delete_record` accept `:swap_record` and `:swap_commit` for optimistic concurrency. `list_records` accepts `:limit` (1-100), `:cursor` and `:reverse`.

## AT-URIs and CIDs

Records are identified by `at://[did]/[collection]/[rkey]`:

```
at://did:plc:abc123xyz/app.bsky.feed.post/3kxyz789
```

Rkeys default to timestamp identifiers (TIDs), which give you ordering and collision avoidance for free. You can pass a custom `:rkey` on create, but prefer TIDs unless you have a reason.

CIDs are content hashes, used for versioning and concurrency control:

```elixir
{:ok, current} = Repo.get_record(session, params)

case Repo.put_record(session, %{
  repo: session.did,
  collection: collection,
  rkey: rkey,
  record: updated,
  swap_record: current.cid  # only succeeds if nobody else touched it
}) do
  {:ok, result} -> result
  {:error, %{error: "InvalidSwap"}} -> # record changed underneath you
end
```

## Collections

Standard Bluesky collections:

```elixir
"app.bsky.feed.post"     # posts
"app.bsky.feed.like"     # likes
"app.bsky.feed.repost"   # reposts
"app.bsky.graph.follow"  # follows
"app.bsky.graph.block"   # blocks
"app.bsky.actor.profile" # profile
```

Custom collections work the same way with your own NSID. See [Custom Lexicons](custom-lexicons.md) for validated writes.

## Pagination

```elixir
def fetch_all(session, repo, collection, cursor \\ nil, acc \\ []) do
  params = %{repo: repo, collection: collection, limit: 100}
  params = if cursor, do: Map.put(params, :cursor, cursor), else: params

  case Repo.list_records(session, params) do
    {:ok, %{records: records, cursor: nil}} -> {:ok, acc ++ records}
    {:ok, %{records: records, cursor: next}} -> fetch_all(session, repo, collection, next, acc ++ records)
    {:error, reason} -> {:error, reason}
  end
end
```

## Errors

```elixir
case Repo.create_record(session, params) do
  {:ok, result} -> result
  {:error, %{error: "InvalidRecord"}} -> # doesn't conform to the lexicon
  {:error, %{error: "InvalidSwap"}} ->   # concurrent modification
  {:error, %{error: "RecordNotFound"}} -> # gone
  {:error, reason} -> # network or other
end
```
