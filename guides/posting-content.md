# Posting Content

## Text posts

```elixir
{:ok, post} = ProtoRune.Bsky.post(session, "Hello Bluesky!")
# post.uri and post.cid identify the record
```

Options:

- `:langs`: language codes (omitted when not given)
- `:reply_to`: AT-URI of the post to reply to
- `:created_at`: custom timestamp (default: now)

```elixir
{:ok, post} = ProtoRune.Bsky.post(session, "Olá!", langs: ["pt"])
```

## Rich text

`ProtoRune.RichText` builds mentions, links and hashtags with the facets AT Protocol expects. Byte offsets are calculated for you.

```elixir
alias ProtoRune.RichText

{:ok, rt} =
  RichText.new()
  |> RichText.text("Hello ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text("! Check out ")
  |> RichText.link("ProtoRune", "https://github.com/zoedsoupe/proto_rune")
  |> RichText.text(" ")
  |> RichText.hashtag("elixir")
  |> RichText.build()

{:ok, post} = ProtoRune.Bsky.post(session, rt)
```

Builder functions: `text/2`, `mention/2`, `link/3`, `hashtag/2`, then `build/1` to finalize. If mention DID resolution fails, the text is added without a facet, so posts never fail on identity lookups.

Utilities: `to_plain_text/1` and `facets/1` inspect a built rich text.

Since the builder is a plain value, you can build conditionally:

```elixir
rt = RichText.new() |> RichText.text("Hello")

rt = if include_mention?, do: RichText.mention(rt, "alice.bsky.social"), else: rt

{:ok, post_data} = rt |> RichText.text("!") |> RichText.build()
```

## Replies and deletes

```elixir
{:ok, reply} = ProtoRune.Bsky.post(session, "Great point!", reply_to: post.uri)

:ok = ProtoRune.Bsky.delete_post(session, post.uri)
```

When `:reply_to` is set, `Bsky.post/3` fetches the parent record to build the correct root and parent references. If the parent is itself a reply, its root is preserved.

## Limits and languages

- The built-in post schema limits text to 300 according to its Peri string constraint. It does not explicitly count grapheme clusters; the PDS may also validate the record.
- Set accurate `:langs` for discovery and accessibility: `["en"]`, `["pt"]`, or `["en", "pt"]` for multilingual posts.

## Errors

```elixir
case ProtoRune.Bsky.post(session, content) do
  {:ok, post} -> post.uri
  {:error, %ProtoRune.XRPC.Error{reason: reason}} -> reason
  {:error, reason} -> # network or other
end
```
