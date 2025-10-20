# Repository Operations (Advanced)

This guide covers low-level repository operations for advanced use cases. Most applications should use the high-level Bsky helpers instead.

## Understanding Repositories

In AT Protocol, a repository is a collection of records stored in a user's Personal Data Server (PDS). Each record has:

- **Collection**: Record type (e.g., "app.bsky.feed.post")
- **Rkey**: Record key (unique identifier within the collection)
- **Record**: The actual data conforming to a lexicon schema

## Repository Functions

All repository functions are in `ProtoRune.Atproto.Repo`.

### Create Record

Create a new record in a collection:

```elixir
alias ProtoRune.Atproto.Repo

{:ok, result} = Repo.create_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  record: %{
    "$type" => "app.bsky.feed.post",
    "text" => "Hello from low-level API",
    "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601(),
    "langs" => ["en"]
  }
})

# Result contains:
# %{uri: "at://did/collection/rkey", cid: "bafy..."}
```

### Get Record

Fetch a specific record:

```elixir
{:ok, record} = Repo.get_record(session, %{
  repo: "did:plc:abc123",
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
})
```

Parameters:

- `:repo` - DID of the repository owner
- `:collection` - Collection name
- `:rkey` - Record key
- `:cid` - (optional) Specific version by CID

### Update Record

Update an existing record:

```elixir
{:ok, result} = Repo.put_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz...",
  record: %{
    "$type" => "app.bsky.feed.post",
    "text" => "Updated text",
    "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601(),
    "langs" => ["en"]
  }
})
```

Optional parameters:

- `:validate` - Validate record against lexicon (default: true)
- `:swap_record` - CID for optimistic concurrency control
- `:swap_commit` - Commit CID for atomic operations

### Delete Record

Remove a record from a collection:

```elixir
{:ok, result} = Repo.delete_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
})
```

Optional parameters:

- `:swap_record` - CID for optimistic concurrency control
- `:swap_commit` - Commit CID for atomic operations

### List Records

List all records in a collection:

```elixir
{:ok, result} = Repo.list_records(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  limit: 50
})

# Result contains:
# %{records: [...], cursor: "..."}
```

Optional parameters:

- `:limit` - Max records to return (1-100)
- `:cursor` - Pagination cursor
- `:reverse` - Reverse chronological order

## AT-URI Format

AT-URIs identify records in the format:

```
at://[did]/[collection]/[rkey]
```

Example:

```
at://did:plc:abc123xyz/app.bsky.feed.post/3kxyz789
```

Components:

- `did:plc:abc123xyz` - Repository owner's DID
- `app.bsky.feed.post` - Collection name
- `3kxyz789` - Record key

## Working with Collections

### Standard Collections

Common Bluesky collections:

```elixir
# Posts
"app.bsky.feed.post"

# Likes
"app.bsky.feed.like"

# Reposts
"app.bsky.feed.repost"

# Follows
"app.bsky.graph.follow"

# Blocks
"app.bsky.graph.block"

# Profile
"app.bsky.actor.profile"
```

### Custom Collections

You can create custom collections if you've defined lexicons:

```elixir
{:ok, result} = Repo.create_record(session, %{
  repo: session.did,
  collection: "com.example.custom.record",
  record: %{
    "$type" => "com.example.custom.record",
    "data" => "custom value"
  }
})
```

## Record Keys

Record keys (rkeys) are base32-encoded TIDs (timestamp identifiers) by default:

```elixir
# Example rkey
"3kxyz789abc"
```

You can optionally specify custom rkeys:

```elixir
{:ok, result} = Repo.create_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  rkey: "custom-key-123",  # Custom rkey
  record: record_data
})
```

However, using TID-based rkeys is recommended for proper ordering and collision avoidance.

## Content Identifiers (CIDs)

CIDs are cryptographic hashes of record content:

```elixir
# Example CID
"bafyreigp5..."
```

CIDs enable:

- **Versioning**: Track record changes
- **Verification**: Ensure content hasn't been tampered with
- **Deduplication**: Identify identical content

### Using CIDs for Concurrency Control

Prevent conflicting updates with swap operations:

```elixir
# Get current record
{:ok, current} = Repo.get_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
})

# Update only if CID matches (no one else modified it)
case Repo.put_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz...",
  record: updated_record,
  swap_record: current.cid  # Only succeed if CID still matches
}) do
  {:ok, result} ->
    # Update succeeded
    IO.puts("Record updated")

  {:error, %{error: "InvalidSwap"}} ->
    # Someone else modified the record
    IO.puts("Record was modified by another client")

  {:error, reason} ->
    # Other error
    IO.puts("Update failed: #{inspect(reason)}")
end
```

## Pagination

List operations support cursor-based pagination:

```elixir
defmodule RecordFetcher do
  alias ProtoRune.Atproto.Repo

  def fetch_all_posts(session, repo_did) do
    fetch_posts(session, repo_did, nil, [])
  end

  defp fetch_posts(session, repo_did, cursor, acc) do
    params = %{
      repo: repo_did,
      collection: "app.bsky.feed.post",
      limit: 100
    }

    params = if cursor, do: Map.put(params, :cursor, cursor), else: params

    case Repo.list_records(session, params) do
      {:ok, %{records: records, cursor: next_cursor}} ->
        all_records = acc ++ records

        if next_cursor do
          fetch_posts(session, repo_did, next_cursor, all_records)
        else
          {:ok, all_records}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Usage
{:ok, all_posts} = RecordFetcher.fetch_all_posts(session, session.did)
```

## Error Handling

Repository operations can fail for various reasons:

```elixir
case Repo.create_record(session, params) do
  {:ok, result} ->
    result

  {:error, %{error: "InvalidRecord"}} ->
    # Record doesn't conform to lexicon
    IO.puts("Invalid record structure")

  {:error, %{error: "InvalidSwap"}} ->
    # CID mismatch in swap operation
    IO.puts("Concurrent modification detected")

  {:error, %{error: "RecordNotFound"}} ->
    # Record doesn't exist
    IO.puts("Record not found")

  {:error, reason} ->
    # Network or other errors
    IO.puts("Operation failed: #{inspect(reason)}")
end
```

## Best Practices

### Use High-Level Helpers When Possible

For common operations, use `ProtoRune.Bsky` helpers:

```elixir
# Good: Use helper
ProtoRune.Bsky.post(session, "Hello")

# Only when needed: Use low-level
Repo.create_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  record: post_record
})
```

### Validate Records

Always ensure records conform to their lexicon schemas:

```elixir
# Validation happens automatically by default
{:ok, result} = Repo.create_record(session, %{
  repo: session.did,
  collection: "app.bsky.feed.post",
  record: record,
  validate: true  # Default
})
```

### Handle Concurrent Modifications

Use swap parameters for atomic operations:

```elixir
{:ok, current} = Repo.get_record(session, params)

# Modify record
updated = Map.put(current.value, :field, new_value)

# Update with CID check
Repo.put_record(session, %{
  repo: session.did,
  collection: collection,
  rkey: rkey,
  record: updated,
  swap_record: current.cid
})
```

### Paginate Large Collections

Don't fetch all records at once:

```elixir
# Bad: Unbounded
Repo.list_records(session, %{repo: did, collection: collection})

# Good: Paginated
Repo.list_records(session, %{
  repo: did,
  collection: collection,
  limit: 50
})
```

## When to Use Repository Operations

Use low-level repository operations when you need to:

- Create custom record types
- Implement optimistic concurrency control
- Batch process records efficiently
- Work with non-standard collections
- Build custom protocols on AT Protocol

For standard Bluesky operations (posts, likes, follows), use the high-level `ProtoRune.Bsky` API instead.
