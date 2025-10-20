# Posting Content

ProtoRune provides ergonomic functions for creating posts with text, rich text formatting, and media.

## Simple Text Posts

The most basic operation is posting plain text:

```elixir
{:ok, post} = ProtoRune.Bsky.post(session, "Hello Bluesky!")
```

The returned post contains:

```elixir
%{
  uri: "at://did:plc:abc123/app.bsky.feed.post/3k...",
  cid: "bafyrei...",
  ...
}
```

## Post Options

The `post/3` function accepts options for language and threading:

```elixir
{:ok, post} = ProtoRune.Bsky.post(
  session,
  "Hello world!",
  langs: ["en"],
  created_at: DateTime.utc_now()
)
```

### Available Options

- `:langs` - List of language codes (default: `["en"]`)
- `:reply_to` - AT-URI of post to reply to
- `:created_at` - Custom timestamp (default: current time)

## Rich Text

Rich text allows you to add mentions, links, and hashtags with proper facets for the AT Protocol.

### Basic Rich Text

Use the `ProtoRune.RichText` module to build rich text:

```elixir
alias ProtoRune.RichText

{:ok, rt} =
  RichText.new()
  |> RichText.text("Hello ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text("! Check out ")
  |> RichText.link("this project", "https://github.com/zoedsoupe/proto_rune")
  |> RichText.text(" ")
  |> RichText.hashtag("elixir")
  |> RichText.build()

{:ok, post} = ProtoRune.Bsky.post(session, rt)
```

### Rich Text Functions

#### `RichText.new()`

Creates a new rich text builder:

```elixir
rt = RichText.new()
```

#### `RichText.text(rt, content)`

Appends plain text:

```elixir
rt = RichText.new() |> RichText.text("Hello world")
```

#### `RichText.mention(rt, handle)`

Adds a mention with automatic DID resolution:

```elixir
rt = RichText.new() |> RichText.mention("alice.bsky.social")
# Results in: "@alice.bsky.social" with mention facet
```

If DID resolution fails, the text is added without a facet (as plain text). This ensures posts always succeed even if identity resolution has issues.

#### `RichText.link(rt, text, url)`

Adds a clickable link:

```elixir
rt = RichText.new() |> RichText.link("click here", "https://example.com")
```

#### `RichText.hashtag(rt, tag)`

Adds a hashtag:

```elixir
rt = RichText.new() |> RichText.hashtag("elixir")
# Results in: "#elixir" with tag facet
```

#### `RichText.build(rt)`

Finalizes the rich text and returns a map suitable for posting:

```elixir
{:ok, post_data} = RichText.build(rt)
# post_data contains :text and :facets
```

### Complex Rich Text Example

```elixir
alias ProtoRune.RichText

{:ok, rt} =
  RichText.new()
  |> RichText.text("Excited to announce ")
  |> RichText.link("ProtoRune v0.2.0", "https://hex.pm/packages/proto_rune")
  |> RichText.text(" - an Elixir SDK for AT Protocol!\\n\\n")
  |> RichText.text("Features:\\n")
  |> RichText.text("- Type-safe API\\n")
  |> RichText.text("- Bot framework\\n")
  |> RichText.text("- Rich text support\\n\\n")
  |> RichText.text("Thanks to ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text(" for testing! ")
  |> RichText.hashtag("elixir")
  |> RichText.text(" ")
  |> RichText.hashtag("atproto")
  |> RichText.build()

{:ok, post} = ProtoRune.Bsky.post(session, rt)
```

### Rich Text Utilities

Extract plain text from rich text:

```elixir
plain = RichText.to_plain_text(rt)
```

Get facets:

```elixir
facets = RichText.facets(rt)
```

## Replies

Reply to posts using the `:reply_to` option:

```elixir
{:ok, reply} = ProtoRune.Bsky.post(
  session,
  "Great point!",
  reply_to: "at://did:plc:xyz/app.bsky.feed.post/3k..."
)
```

Note: The current MVP implementation does not fetch parent post details, so replies work but without proper threading context. This will be enhanced in future versions.

## Deleting Posts

Delete your posts by URI:

```elixir
:ok = ProtoRune.Bsky.delete_post(session, post.uri)
```

## Best Practices

### Text Length

AT Protocol has a 3000 grapheme limit for post text. Be mindful of this when creating posts:

```elixir
text = "Very long post content..."

if String.length(text) > 3000 do
  IO.puts("Post too long, truncating")
  text = String.slice(text, 0, 2999)
end

{:ok, post} = ProtoRune.Bsky.post(session, text)
```

### Language Tags

Always specify accurate language tags for better discovery and accessibility:

```elixir
# English post
ProtoRune.Bsky.post(session, "Hello", langs: ["en"])

# Portuguese post
ProtoRune.Bsky.post(session, "Olá", langs: ["pt"])

# Multilingual post
ProtoRune.Bsky.post(session, "Hello / Olá", langs: ["en", "pt"])
```

### Handle Errors Gracefully

```elixir
case ProtoRune.Bsky.post(session, content) do
  {:ok, post} ->
    IO.puts("Posted successfully: #{post.uri}")

  {:error, %{error: "InvalidRecord"}} ->
    IO.puts("Post content is invalid")

  {:error, reason} ->
    IO.puts("Failed to post: #{inspect(reason)}")
end
```

### Building Rich Text Incrementally

Rich text can be built conditionally:

```elixir
rt = RichText.new()
|> RichText.text("Hello")

rt = if include_mention? do
  RichText.mention(rt, "alice.bsky.social")
else
  rt
end

rt = RichText.text(rt, "!")

{:ok, post_data} = RichText.build(rt)
```

## Working with Post URIs

Post URIs follow the format `at://did/collection/rkey`:

```elixir
uri = "at://did:plc:abc123/app.bsky.feed.post/3kxyz"

# Extract components
["did:plc:abc123", "app.bsky.feed.post", "3kxyz"] =
  String.split(String.trim_leading(uri, "at://"), "/")
```

ProtoRune handles URI parsing internally for operations like delete, unlike, unfollow, etc.

## Future Features

Features planned for future releases:

- **Image upload** - Attach images to posts
- **Video upload** - Share video content
- **External embeds** - Rich previews for links
- **Quote posts** - Quote other posts with comments
- **Thread creation** - Create multi-post threads easily

See the roadmap for implementation timelines.
