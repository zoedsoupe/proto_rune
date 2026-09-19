# Custom Lexicons

Bluesky's `app.bsky.*` collections are just lexicons, and AT Protocol lets you define your own the same way. `create_record/3` and `put_record/3` accept any collection NSID as a string, and you can plug in your own validation schemas.

The workflow: define a lexicon, generate a Peri schema from it, write validated records.

## 1. Define your lexicon

A lexicon is a JSON document describing your record type. Save it under `priv/lexicons`:

```json
{
  "lexicon": 1,
  "id": "com.example.status",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["status", "createdAt"],
        "properties": {
          "status": {"type": "string", "maxLength": 300},
          "createdAt": {"type": "string", "format": "datetime"}
        }
      }
    }
  }
}
```

Building on someone else's lexicon? Copy their published JSON files the same way.

## 2. Generate Peri schemas

```bash
mix proto_rune.gen.lexicons --path priv/lexicons --output lib/my_app/lexicons
```

One module per lexicon, following the NSID (`com.example.status` → `ProtoRune.Lexicon.Com.Example.Status`), with a schema per def and helpers:

```elixir
ProtoRune.Lexicon.Com.Example.Status.get_schema(:main)
ProtoRune.Lexicon.Com.Example.Status.validate(record)
```

Commit the generated files and re-run with `--force` when lexicons change.

## 3. Write validated records

Pass the schema via `:schema`. The record is validated before anything hits the PDS:

```elixir
alias ProtoRune.Atproto.Repo

schema = ProtoRune.Lexicon.Com.Example.Status.get_schema(:main)

{:ok, result} =
  Repo.create_record(
    session,
    %{
      repo: ProtoRune.Session.did(session),
      collection: "com.example.status",
      record: %{
        "$type" => "com.example.status",
        "status" => "hacking on atproto",
        "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    },
    schema: schema
  )
```

On mismatch you get `{:error, errors}` and no request is made. `put_record/3` works the same, with a required `:rkey`.

## The unvalidated default

Without `:schema`, records to unknown collections are sent as-is:

```elixir
{:ok, result} =
  Repo.create_record(session, %{
    repo: ProtoRune.Session.did(session),
    collection: "com.example.status",
    record: %{"anything" => "goes"}
  })
```

Typos and malformed records are then only caught by the PDS, if it validates at all. Pass `schema:` for any collection you write to regularly.

## Built-in Bluesky collections

The known collections keep their built-in validation:

- Atom collections (`:post`, `:like`, `:repost`, `:generator`, `:threadgate`, `:postgate`) map to `"app.bsky.feed.<name>"`; posts, likes and reposts validate against the built-in schemas. Unknown atoms fail with `{:error, {:unsupported_collection, collection}}`, which catches typos like `:psot`.
- The string forms (`"app.bsky.feed.post"` etc.) validate against the same built-in schemas.

Passing `schema:` overrides the built-in validation when both apply.
