# ProtoRune Roadmap

**Mission**: Build a production-ready, type-safe AT Protocol SDK and bot framework for Elixir that leverages BEAM's strengths for reliability and concurrency.

**Current Status**: v0.2.0 MVP ✅ Complete | Next: v0.3.0 in development

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

## v0.3.0 - OAuth & Real-Time 🚧 In Planning

**Timeline**: Q1 2025 (8-10 weeks)

**Focus**: Production authentication and real-time capabilities

### Authentication & Security
- [ ] OAuth client implementation (issue #15)
  - Authorization code flow
  - PKCE support for public clients
  - Token exchange and refresh
  - Redirect URI handling
- [ ] Improved rate limiting and backoff (issue #30)
  - Track requests per minute
  - Exponential backoff on rate limits
  - Configurable retry logic
- [ ] Session security enhancements
  - Secure token storage helpers
  - Token encryption utilities

### Real-Time Events
- [ ] Firehose integration (issue #16)
  - WebSocket connection to firehose
  - CAR file parsing
  - Event streaming
  - Basic filtering
- [ ] Bot firehose strategy
  - Real-time event processing
  - High-throughput handling
  - Event buffering

### API Enhancements
- [ ] Fix reply threading (issue #22) **Priority**
  - Fetch parent post for CID
  - Determine thread root properly
  - Build correct reply references
- [ ] Profile updates (issue #23)
  - Update display name, description
  - Avatar and banner upload
- [ ] Search functionality (issue #24)
  - Search posts by text
  - Search actors by name/handle

### Developer Experience
- [ ] Working example scripts (issue #20) **Priority**
  - Simple post script
  - Rich text post with mentions
  - Auto-responder bot
  - Timeline fetcher
- [ ] Telemetry integration (issue #27)
  - Bot event metrics
  - Poll success/failure tracking
  - Rate limit monitoring

---

## v0.4.0 - Media & Advanced Features 📋 Planned

**Timeline**: Q2 2025 (10-12 weeks)

**Focus**: Media handling and advanced protocol features

### Media Support
- [ ] Blob upload implementation (issue #18)
  - Image upload and compression
  - Video upload support
  - Thumbnail generation
  - Progress tracking
- [ ] Post embeds (issue #26)
  - Image embeds with alt text
  - External link embeds with preview
  - Quote posts
  - Video embeds

### Advanced Features
- [ ] Jetstream integration (issue #17)
  - Jetstream client
  - Filtered event subscriptions
  - Consumer group support
- [ ] Feed generator SDK (issue #19)
  - Custom feed algorithm framework
  - Feed publication helpers
  - Feed testing utilities
- [ ] Graph operations expansion (issue #25)
  - List follows/followers with pagination
  - Block/mute lists
  - List creation and management

### Bot Framework Enhancements
- [ ] State persistence (issue #29)
  - Optional persist_state/1 callback
  - Automatic periodic saving
  - State recovery on restart
- [ ] Advanced event handling
  - Event filtering by criteria
  - Message queuing for high throughput
  - Multi-account bot support

### Developer Tools
- [ ] RichText markdown parser (issue #28)
  - Parse @mentions, #hashtags, [links](url)
  - Automatic facet generation from markdown
- [ ] Comprehensive test coverage (issue #21)
  - Edge case testing
  - Network failure simulation
  - Concurrent operation tests
  - Integration test suite

---

## v0.5.0+ - Future Enhancements 💭 Ideas

**Timeline**: Q3 2025+

**Focus**: Advanced features and ecosystem integration

### Potential Features
- Merkle Search Tree implementation for efficient sync
- Ozone (moderation) integration
- Custom lexicon support
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

### Priority System

**High Priority** (v0.3.0 blockers):
- Issue #22: Reply threading
- Issue #20: Working examples
- Issue #15: OAuth support

**Medium Priority** (v0.3.0 enhancements):
- Issue #30: Rate limiting
- Issue #16: Firehose
- Issue #27: Telemetry

**Low Priority** (v0.4.0+):
- Issue #28: Markdown parser
- Issue #29: State persistence
- Issue #19: Feed generator SDK

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

**Last Updated**: 2025-01-20
**Maintained By**: [@zoedsoupe](https://github.com/zoedsoupe)
**Status**: Living document - updated as development progresses
