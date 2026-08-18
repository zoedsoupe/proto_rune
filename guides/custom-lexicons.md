# Custom Lexicons

Bluesky's `app.bsky.*` collections are just lexicons. AT Protocol lets any application define its own record types the same way, and ProtoRune can write to them: `create_record/3` and `put_record/3` accept any collection NSID as a string, and you can plug in your own validation schemas.

This guide walks through the full workflow: define a lexicon, generate a Peri schema from it, and write validated records to your custom collection.

## 1. Define Your Lexicon

A lexicon is a JSON document describing your record type. Save it in your application, for example under `priv/lexicons`:

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

If you are building on someone else's lexicon, copy their published JSON files the same way.

## 2. Generate Peri Schemas

Run the generator task, pointing it at your lexicons and an output directory:

```bash
mix proto_rune.gen.lexicons --path priv/lexicons --output lib/my_app/lexicons
```

For each lexicon this writes one module, following the NSID:

```
lib/my_app/lexicons/com/example/status.ex
```

The generated module defines a Peri schema per def and a couple of helpers:

```elixir
# Generated from com.example.status
ProtoRune.Lexicon.Com.Example.Status.get_schema(:main)
ProtoRune.Lexicon.Com.Example.Status.validate(record)
```

Note that generated module names always live under the `ProtoRune.Lexicon` namespace, derived from the lexicon ID. Commit the generated files to your repository and re-run the task (with `--force`) whenever the lexicons change.

## 3. Write Records with Validation

Pass the generated schema to `create_record/3` or `put_record/3` via the `:schema` option. The record is validated before anything is sent to the PDS:

```elixir
alias ProtoRune.Atproto.Repo

schema = ProtoRune.Lexicon.Com.Example.Status.get_schema(:main)

{:ok, result} =
  Repo.create_record(
    session,
    %{
      repo: session.did,
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

If the record does not match the schema, the call returns `{:error, errors}` and no request is made:

```elixir
{:error, errors} =
  Repo.create_record(
    session,
    %{repo: session.did, collection: "com.example.status", record: %{}},
    schema: schema
  )
```

`put_record/3` works the same way, with a required `:rkey`:

```elixir
{:ok, result} =
  Repo.put_record(
    session,
    %{
      repo: session.did,
      collection: "com.example.status",
      rkey: "self",
      record: record
    },
    schema: schema
  )
```

## The Unvalidated Default

The `:schema` option is opt-in. Without it, records written to collections ProtoRune does not know about are sent to the PDS exactly as given:

```elixir
# No client-side validation: the record is sent as-is
{:ok, result} =
  Repo.create_record(session, %{
    repo: session.did,
    collection: "com.example.status",
    record: %{"anything" => "goes"}
  })
```

Be careful with this: typos and malformed records are only caught by the PDS, and only if it validates the lexicon. Passing `schema:` is the recommended default for any collection you write to regularly.

## Built-in Bluesky Collections

The known Bluesky collections keep their built-in validation in both write forms:

- Atom collections (`:post`, `:like`, `:repost`) are restricted to the built-in set, encoded as `"app.bsky.feed.<name>"`, and validated against the built-in schemas. Unknown atoms fail with `{:error, {:unsupported_collection, collection}}`, which catches typos like `:psot`.
- The string forms `"app.bsky.feed.post"`, `"app.bsky.feed.like"`, and `"app.bsky.feed.repost"` are validated against the same built-in schemas.

Passing `schema:` overrides the built-in validation when both apply.
