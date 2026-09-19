# ProtoRune

[![Hex version](https://img.shields.io/hexpm/v/proto_rune.svg)](https://hex.pm/packages/proto_rune)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/proto_rune)
[![Hex downloads](https://img.shields.io/hexpm/dt/proto_rune.svg)](https://hex.pm/packages/proto_rune)
[![License](https://img.shields.io/hexpm/l/proto_rune.svg)](https://github.com/zoedsoupe/proto_rune/blob/main/LICENSE)

A type-safe Elixir SDK for the AT Protocol, with a built-in bot framework. The code is generated from the official lexicons and sessions are explicit, so there is no hidden global state to hunt down at 3am.

## Installation

```elixir
def deps do
  [
    {:proto_rune, "~> 0.5.3"} # x-release-please-version
  ]
end
```

## Quick start

Login with your handle and an [app password](https://bsky.app/settings/app-passwords), then post:

```elixir
{:ok, session} = ProtoRune.login("you.bsky.social", "your-app-password")

{:ok, post} = ProtoRune.Bsky.post(session, "Hello from Elixir!")
```

That's the whole setup. From here you can like, repost, follow, read timelines, resolve handles and so on, everything takes the session as the first argument:

```elixir
{:ok, timeline} = ProtoRune.Bsky.get_timeline(session, limit: 20)
{:ok, like} = ProtoRune.Bsky.like(session, post.uri, post.cid)
{:ok, did} = ProtoRune.resolve_handle("alice.bsky.social")
```

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

## Docs

Full API reference on [hexdocs.pm/proto_rune](https://hexdocs.pm/proto_rune). Guides:

- [Getting started](guides/getting-started.md)
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
