# ProtoRune Roadmap

**Mission**: Build a production-ready, type-safe AT Protocol SDK and bot framework for Elixir that leverages BEAM's strengths for reliability and concurrency.

**Current Status**: v0.3.1 released ✅ | Next: v0.4.0 in development

---

## Core Principles

1. **ATProto Alignment**: Reflect AT Protocol's layered architecture (Identity → Repository → Lexicon → Application)
2. **Progressive Disclosure**: Simple tasks are simple, complex tasks are possible
3. **Explicit Over Implicit**: Functional style with explicit session passing, no hidden global state
4. **OTP Native**: Leverage GenServers, Supervisors, and Telemetry for reliability
5. **Type Safety**: Runtime validation with Peri schemas

---

## v0.2.0 MVP ✅ Complete

**Status**: Released - Production ready for basic use cases

### What's Included

#### Core Protocol Layer
- ✅ XRPC client with explicit session management
- ✅ Identity resolution (DID/handle) with caching
- ✅ Repository operations (create, get, put, delete, list records)
- ✅ Session management with automatic token refresh
- ✅ Structured error handling with proper error tuples

#### Bluesky High-Level API
- ✅ Post creation with text and rich text
- ✅ Social interactions: like, unlike, repost, unrepost
- ✅ Graph operations: follow, unfollow, block, unblock, mute, unmute
- ✅ Timeline and thread retrieval
- ✅ Profile operations: get profile, get multiple profiles
- ✅ Notifications: list, get unread count, mark as seen
- ✅ RichText builder with automatic facet generation for mentions, links, hashtags

#### Bot Framework
- ✅ OTP-based bot behavior with GenServer
- ✅ Polling strategy for notifications
- ✅ Event handlers for: mention, reply, like, repost, follow, quote
- ✅ Automatic login and session management
- ✅ Supervision tree support for reliability

#### Developer Experience
- ✅ Comprehensive guides (getting started, authentication, posting, bots, repository operations)
- ✅ User-friendly README with clear examples
- ✅ 130+ passing tests
- ✅ Proper documentation structure in ExDoc

#### Infrastructure
- ✅ Lexicon generator and type mapper (code exists)
- ✅ Mix task for lexicon generation
- ✅ Git submodule with official AT Protocol lexicons

### Known Limitations (v0.2.0)

- Reply threading uses stub values (issue #22)
- No lexicon schemas generated yet (pending: run mix task)
- Basic error handling (needs edge case coverage - issue #21)

---

## v0.3.0 - OAuth & Real-Time ✅ Released

**Focus**: Production authentication and real-time capabilities

### Authentication & Security
- [x] OAuth client implementation
  - Authorization code flow
  - PKCE support for public clients
  - DPoP proof generation
  - Token exchange and refresh
- [x] Improved rate limiting and backoff
  - Track requests per minute
  - Exponential backoff on rate limits
  - Configurable retry logic
- [x] Session security enhancements
  - Secure token storage helpers (TokenStore behaviour, DETS backend)
  - Token encryption utilities

### Real-Time Events
- [x] Firehose integration
  - WebSocket connection to firehose
  - CAR file parsing
  - Event streaming
  - Basic filtering
- [x] Bot firehose strategy
  - Real-time event processing
  - High-throughput handling

### API Enhancements
- [x] Fix reply threading (fetches parent post, builds correct strong refs)
- [x] Profile updates (display name, description via Bsky.update_profile; blob upload for avatar/banner)
- [x] Actor search (searchActors, searchActorsTypeahead)
- [x] Telemetry integration (bot events, poller metrics)

### Deferred from v0.3.0
- Post search
- Working example scripts

---

## v0.4.0 - Protocol-Generic SDK 🚧 In Development

**Focus**: OAuth sessions first-class for XRPC, `com.atproto.sync` read
surface, generic record writes. Full detail in [PLAN-v0.4.0.md](PLAN-v0.4.0.md).

- [ ] Binary response support in XRPC (`response: :auto | :json | :binary`)
- [ ] Unified `ProtoRune.Session` behaviour with DPoP-bound requests
  - OAuth tokens can read and write, not just authenticate
  - Resource-server DPoP nonce retry
- [ ] OAuth session lifecycle
  - Token revocation
  - Opt-in SessionManager GenServer (proactive refresh, TokenStore persistence)
- [ ] `com.atproto.sync` read surface
  - getBlob, getRepo, describeRepo
  - Minimal MST traversal for repo enumeration (no commit verification yet)
  - com.atproto.identity.resolveHandle endpoint parity
- [ ] Generic record writes
  - createRecord/putRecord accept any collection NSID
  - Opt-in caller-supplied Peri schema validation
  - Lexicon codegen flags (--path, --output) for host apps
- [ ] Test infrastructure: Bypass-based PDS fixture tests

---

## v0.5.0+ - Future Enhancements 💭 Ideas

**Focus**: Media, advanced protocol features, and ecosystem integration

### Potential Features
- Media embeds (images, external links, quote posts, video)
- Jetstream integration
- Feed generator SDK
- Graph operations expansion (lists, pagination)
- Post search
- Bot state persistence
- RichText markdown parser
- Commit/signature verification of repo checkouts
- Merkle Search Tree verification for efficient sync
- Ozone (moderation) integration
- PDS (Personal Data Server) helpers
- Label and moderation tools
- Advanced caching strategies
- Performance optimizations
- Multi-language support for posts

### Community Requests
- Features will be prioritized based on community feedback
- Submit ideas via GitHub Discussions
- Vote on features via GitHub issue reactions

---

## Development Process

### How We Work

**Milestone Structure**: Each version (v0.3.0, v0.4.0) is a milestone with ~8-12 weeks of work

**Issue Tracking**: All features tracked as GitHub issues with labels:
- `enhancement` - New features
- `bug` - Bug fixes
- `documentation` - Docs improvements
- `priority` - High priority items

**Release Criteria**:
- All milestone issues closed
- Tests passing
- Documentation updated
- CHANGELOG.md updated
- Hex package published

### How to Contribute

1. **Pick an Issue**: Check [GitHub Issues](https://github.com/zoedsoupe/proto_rune/issues) for open tasks
2. **Discuss First**: Comment on the issue before starting work
3. **Follow Guidelines**: See [CONTRIBUTING.md](CONTRIBUTING.md) for code standards
4. **Submit PR**: Reference the issue number in your PR
5. **Iterate**: Address code review feedback

---

## Success Metrics

### Technical Quality
- [ ] Test coverage >80%
- [ ] All examples run successfully
- [ ] Zero critical bugs in production
- [ ] Dialyzer clean

### Adoption
- [ ] 100+ GitHub stars
- [ ] 10+ production bots running
- [ ] 5+ external contributors
- [ ] Listed on AT Protocol ecosystem page

### Documentation
- [ ] Complete API documentation
- [ ] 5+ comprehensive guides
- [ ] Video tutorials
- [ ] Community-contributed examples

---

## Resources

- **GitHub**: https://github.com/zoedsoupe/proto_rune
- **Documentation**: https://hexdocs.pm/proto_rune
- **Issues**: https://github.com/zoedsoupe/proto_rune/issues
- **Discussions**: https://github.com/zoedsoupe/proto_rune/discussions
- **AT Protocol Docs**: https://atproto.com

---

## Inspirations

ProtoRune stands on the shoulders of these excellent projects:

- [atcute](https://github.com/mary-ext/atcute) - Lightweight TypeScript ATProto library
- [jacquard](https://github.com/nonbinary-computer/jacquard) - High-performance Rust implementation
- [Peri](https://github.com/zoedsoupe/peri) - Flexible Elixir schema validation
- [Python AT Proto SDK](https://github.com/MarshalX/atproto) - Comprehensive Python implementation

---

**Last Updated**: 2026-08-18
**Maintained By**: [@zoedsoupe](https://github.com/zoedsoupe)
**Status**: Living document - updated as development progresses
