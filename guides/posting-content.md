# Posting Content

## Text posts

```elixir
{:ok, post} = ProtoRune.Bsky.post(session, "Hello Bluesky!")
# post.uri and post.cid identify the record
```

Options:

- `:langs`: language codes (default `["en"]`)
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

Note: the current implementation does not fetch parent post details, so replies work but without full threading context.

## Limits and languages

- Post text is capped at 3000 graphemes, check `String.length/1` before posting.
- Set accurate `:langs` for discovery and accessibility: `["en"]`, `["pt"]`, or `["en", "pt"]` for multilingual posts.

## Errors

```elixir
case ProtoRune.Bsky.post(session, content) do
  {:ok, post} -> post.uri
  {:error, %{error: "InvalidRecord"}} -> # content is invalid
  {:error, reason} -> # network or other
end
```
