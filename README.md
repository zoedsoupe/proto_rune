# ProtoRune

[![Hex version](https://img.shields.io/hexpm/v/proto_rune.svg)](https://hex.pm/packages/proto_rune)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/proto_rune)
[![Hex downloads](https://img.shields.io/hexpm/dt/proto_rune.svg)](https://hex.pm/packages/proto_rune)
[![License](https://img.shields.io/hexpm/l/proto_rune.svg)](https://github.com/zoedsoupe/proto_rune/blob/main/LICENSE)

An Elixir SDK for the AT Protocol. Build your own atproto apps: custom lexicons, your own collections on the user's PDS, OAuth, identity resolution, repo sync. The Bluesky API comes along for the ride. Sessions are explicit, so there is no hidden global state to hunt down at 3am.

## Installation

```elixir
def deps do
  [
    {:proto_rune, "~> 0.6.0"} # x-release-please-version
  ]
end
```

## Quick start

Login with a handle and an [app password](https://bsky.app/settings/app-passwords), then post:

```elixir
{:ok, session} = ProtoRune.login("you.bsky.social", "your-app-password")

{:ok, post} = ProtoRune.Bsky.post(session, "Hello from Elixir!")
```

Everything takes the session as the first argument:

```elixir
{:ok, timeline} = ProtoRune.Bsky.get_timeline(session, limit: 20)
{:ok, like} = ProtoRune.Bsky.like(session, post.uri, post.cid)
{:ok, repost} = ProtoRune.Bsky.repost(session, post.uri, post.cid)
{:ok, follow} = ProtoRune.Bsky.follow(session, "alice.bsky.social")
{:ok, did} = ProtoRune.resolve_handle("alice.bsky.social")
{:ok, doc} = ProtoRune.resolve_did("did:plc:abc123xyz")
```

## Sessions

A session holds the tokens and account info. There are two kinds: app password sessions and OAuth sessions (PAR, PKCE and DPoP, no JWT dependency). Access tokens expire; refresh when needed:

```elixir
{:ok, fresh_session} = ProtoRune.refresh_session(session)
```

For long-running apps, `ProtoRune.SessionManager` keeps a session fresh and persists each rotation encrypted. See the [authentication guide](guides/authentication.md).

## Error handling

Everything returns tagged tuples:

```elixir
case ProtoRune.login(identifier, password) do
  {:ok, session} -> ProtoRune.Bsky.post(session, "Success!")
  {:error, reason} -> IO.puts("Login failed: #{inspect(reason)}")
end
```

## Building on atproto

Bluesky's `app.bsky.*` collections are just lexicons, and your app can define its own the same way. Records live on the user's PDS under your NSID; ProtoRune writes them with validation before anything hits the wire:

```bash
mix proto_rune.gen.lexicons --path priv/lexicons --output lib/my_app/lexicons
```

```elixir
schema = MyApp.Lexicons.Blog.Post.get_schema(:main)

{:ok, %{uri: uri}} =
  ProtoRune.Atproto.Repo.create_record(
    session,
    %{
      repo: ProtoRune.Session.did(session),
      collection: "blog.myapp.post",
      record: %{"$type" => "blog.myapp.post", "title" => "hello atproto"}
    },
    schema: schema
  )
```

Drop lower when you need to: `ProtoRune.Atproto.Repo` for record CRUD with optimistic concurrency, `ProtoRune.Atproto.Sync` to download and verify repository checkouts (CAR files, signed commits), `ProtoRune.Atproto.Identity` for handle/DID resolution, and the XRPC layer for endpoints with no generated module. See the guides for [custom lexicons](guides/custom-lexicons.md), [repository operations](guides/repository-operations.md) and [XRPC](guides/xrpc.md).

## Rich text

```elixir
alias ProtoRune.RichText

{:ok, rt} =
  RichText.new()
  |> RichText.text("Hello ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text("! Check out ")
  |> RichText.link("ProtoRune", "https://github.com/zoedsoupe/proto_rune")
  |> RichText.build()

{:ok, post} = ProtoRune.Bsky.post(session, rt)
```

Byte offsets are calculated for you, mentions and links just work.

## Bots

```elixir
defmodule GreeterBot do
  use ProtoRune.Bot, name: __MODULE__, strategy: :polling

  require Logger

  @impl true
  def get_identifier, do: System.get_env("BOT_IDENTIFIER")

  @impl true
  def get_password, do: System.get_env("BOT_PASSWORD")

  @impl true
  def handle_event(:mention, payload) do
    Logger.info("Mentioned by #{payload.thread.post.author.handle}")
    {:ok, :handled}
  end

  def handle_event(_event, _payload), do: {:ok, :ignored}
end

{:ok, _pid} = GreeterBot.start_link()
```

Bots are OTP processes with polling out of the box, so they fit into your supervision tree like anything else.

## Built with ProtoRune

- [Quintal](https://quintal.blog.br) — a collective blogging platform on atproto, inspired by the old web: personal blogs, human writing, small communities, chronological forever. No engagement metrics, no ads; your data on your PDS. It uses ProtoRune for its own lexicons (prosas, recados, blogrolls) instead of the Bluesky API, which is exactly the point.

## Docs

Full API reference on [hexdocs.pm/proto_rune](https://hexdocs.pm/proto_rune). Guides:

- [Authentication](guides/authentication.md) (app passwords, OAuth, token storage)
- [Posting content](guides/posting-content.md) (rich text, replies, languages)
- [Bot development](guides/bot-development.md)
- [Repository operations](guides/repository-operations.md) (low-level record CRUD)
- [Custom lexicons](guides/custom-lexicons.md)
- [XRPC](guides/xrpc.md) (low-level API)
- [Bluesky cheatsheet](guides/cheatsheets/bluesky.cheatmd) (runnable snippets)

Issues: [github.com/zoedsoupe/proto_rune/issues](https://github.com/zoedsoupe/proto_rune/issues)

## Contributing

Fork, branch, write tests, `mix test`, `mix format`, open a PR. More details in [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

MIT. Built with love by [@zoedsoupe](https://github.com/zoedsoupe).
