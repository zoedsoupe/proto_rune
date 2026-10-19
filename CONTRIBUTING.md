# Contributing to ProtoRune

## Development Setup

1. Fork and clone the repository
2. Install dependencies with `mix deps.get`
3. Run tests with `mix test`

## Code Organization

```
lib/proto_rune/
├── atproto/      # Core AT Protocol
├── bsky/         # Bluesky app features
├── bot/          # Bot framework
├── lexicon/      # Lexicon loading and resolution
└── xrpc/         # XRPC implementation
```

## Code Style

- Run `mix format` before committing
- Ensure 100% type coverage with dialyzer
- Keep functions focused and small
- Document public functions with `@doc` and `@moduledoc`
- Add typespecs to all public functions

## Testing

- Add tests for new features
- Tests should be in `test/` mirroring `lib/` structure
- Run full test suite with `mix test`
- Run dialyzer with `mix dialyzer`

## Pull Requests

1. Create a branch from `main`
2. Write descriptive commit messages
3. Add tests for new functionality
4. Update documentation as needed
5. Submit PR with description of changes

PRs should:

- Have a clear purpose
- Include relevant tests
- Pass CI checks
- Follow code style guidelines
- Include documentation updates

## Lexicons

`priv/lexicons` holds the official AT Protocol lexicon JSON (`app.bsky`, `com.atproto`, `chat.bsky`, `tools.ozone`). `ProtoRune.Lexicon` loads it on first use and inlines every `$ref` into a self-contained Peri schema; `ProtoRune.Lexicon.schema_for/1` returns one for an NSID.

There is no code generation step. Third-party lexicons are the consumer's to provide: point `ProtoRune.Lexicon.load/1` at a directory of your own JSON.

## Release Process

1. Update version in `mix.exs`
2. Update CHANGELOG.md
3. Create GitHub release
4. Publish to Hex.pm

## Questions?

Open an issue or join the github repo discussion forum.
