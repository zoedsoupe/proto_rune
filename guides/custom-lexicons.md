# Custom Lexicons

Bluesky's `app.bsky.*` collections are just lexicons, and AT Protocol lets you define your own the same way. `create_record/3` and `put_record/3` accept any collection NSID as a string, and you can plug in your own validation schemas.

The workflow: define a lexicon, load it at runtime, then write records using its Peri schema.

## 1. Define your lexicon

A lexicon is a JSON document describing your record type. Save it under `priv/my_lexicons`:

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

Building on someone else's lexicon? Save their published JSON files under the same directory.

## 2. Load the lexicon and get its schema

`ProtoRune.Lexicon.load/1` accepts a directory or an explicit list of JSON file paths. Each load replaces the whole registry; it does not merge with the previously loaded set. Include the vendored files when your host lexicons refer to standard AT Protocol or Bluesky lexicons:

```elixir
vendored_files =
  Path.wildcard(Path.join(ProtoRune.Lexicon.vendored_dir(), "**/*.json"))

host_files = Path.wildcard("priv/my_lexicons/**/*.json")

:ok = ProtoRune.Lexicon.load(vendored_files ++ host_files)
{:ok, schema} = ProtoRune.Lexicon.schema_for("com.example.status")
```

`schema_for/1` looks up the `main` def by NSID and returns `{:ok, schema}` or `{:error, reason}`. Use `schema_for/1` again for another def after loading; schemas are built at runtime, with no generated modules.

## 3. Write validated records

Pass the schema via `:schema`. The record is validated before anything hits the PDS:

```elixir
alias ProtoRune.Atproto.Repo

{:ok, result} =
  Repo.create_record(
    session,
    %{
      repo: ProtoRune.Session.did(session),
      collection: "com.example.status",
      record: %{
        :"$type" => "com.example.status",
        status: "hacking on atproto",
        :"createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    },
    schema: schema
  )
```

Lexicon-derived Peri schemas key properties by atoms with the exact spelling from the JSON. For example, `"createdAt"` must be `:"createdAt"` in the record passed to Repo; it is not `:created_at`. This differs from high-level Bluesky helpers, whose built-in schemas use Elixir-style snake-case keys such as `:created_at`. Repo validates before its XRPC layer converts keys for the wire.

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

The known collections keep their built-in validation: the NSID strings
`"app.bsky.feed.post"`, `"app.bsky.feed.like"` and `"app.bsky.feed.repost"`
validate against the built-in schemas.

Passing `schema:` overrides the built-in validation when both apply.
