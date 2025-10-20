# ProtoRune MVP Roadmap

> **Goal**: Ship v0.2.0 - A production-ready Elixir SDK for AT Protocol with focus on Bluesky operations and bot development
>
> **Timeline**: 8-12 weeks
>
> **Status**: Planning → Implementation

---

## Core Principles

Before diving into phases, these principles guide every decision:

1. **ATProto Alignment**: Every API design decision must reflect ATProto's layered architecture (Identity → Repository → Lexicon → Application)
2. **Progressive Disclosure**: Simple tasks take one line, complex tasks are possible with low-level access
3. **Explicit Over Implicit**: Pass sessions/clients explicitly (functional style), avoid hidden global state
4. **OTP Native**: Leverage GenServers, Supervisors, and Telemetry for reliability
5. **Type Safety**: Runtime validation via Peri schemas generated from official lexicons

---

## Phase 1: Lexicon Code Generation (Weeks 1-2)

### Objective
Generate Peri schemas from ATProto lexicon JSON files to provide type-safe, validated data structures for all operations.

### Why Peri, Not Ecto?
- **Problem**: ATProto has unions, "unknown" types, and dynamic refs - Ecto's embedded schemas are rigid and database-focused
- **Solution**: Peri schemas are just data structures with validation, perfect for protocol types

### Core Concept
Lexicons define the shape of all ATProto data. We parse JSON lexicons at compile-time and generate Elixir modules with validation functions.

### What Gets Generated

**Input**: `priv/atproto/lexicons/app/bsky/feed/post.json`
**Output**: `ProtoRune.Lexicon.App.Bsky.Feed.Post` module

The generated module provides:
- Named schemas (`:main`, `:reply_ref`, etc.)
- Validation functions (`validate/1`, `validate!/1`)
- Type specs
- Documentation from lexicon descriptions

### Simple API Example

```elixir
# Users will validate data like this:
alias ProtoRune.Lexicon.App.Bsky.Feed.Post

post_data = %{
  text: "Hello Bluesky!",
  created_at: DateTime.utc_now(),
  langs: ["en"]
}

# Returns {:ok, validated_map} or {:error, reasons}
{:ok, valid_post} = Post.validate(post_data)

# Bang version raises on invalid data
valid_post = Post.validate!(post_data)
```

### Implementation Strategy (Simplest Path)

**1. Type Mapping**
- Create `ProtoRune.Lexicon.TypeMapper` module
- Map ATProto types to Peri types:
  - `"string"` → `:string`
  - `"integer"` → `:integer`
  - `"union"` → `{:oneof, [types]}`
  - `"ref"` → Module reference
  - `"unknown"` → `:any`
  - `"array"` → `{:list, type}`

**2. Module Generation**
- Create `ProtoRune.Lexicon.Generator` module
- For each lexicon:
  - Parse JSON structure
  - Extract all `defs` (main, nested objects)
  - Generate `defschema` calls for each def
  - Add helper functions (`validate/1`, etc.)
  - Add moduledoc with lexicon description

**3. Mix Task**
- Create `mix proto_rune.gen.lexicons`
- Recursively find all `*.json` in `priv/atproto/lexicons/`
- Build dependency graph (some lexicons reference others)
- Generate in topological order
- Write to `lib/proto_rune/lexicon/generated/`

**4. Compile Hook**
- Add custom compiler in `mix.exs`
- Auto-regenerate if lexicons change
- Skip if generated files are up-to-date

### Key Decisions

**Q: What about nested objects and refs?**
- Nested objects get their own `defschema` in the same module
- Refs become module aliases (`ProtoRune.Lexicon.Com.Atproto.Repo.StrongRef`)

**Q: What about procedures and queries?**
- Generate separate schemas for `input`, `output`, and `parameters`
- Example: `GetTimeline.Parameters`, `GetTimeline.Output`

**Q: What about backwards compatibility?**
- Generated code is committed to git
- Regeneration only happens on lexicon submodule update
- Users can pin to specific lexicon versions

### Success Criteria
- [ ] `mix proto_rune.gen.lexicons` generates 200+ modules
- [ ] All core Bluesky lexicons compile without errors
- [ ] Can validate a `Post` record successfully
- [ ] Generated modules have proper documentation

---

## Phase 2: Core Protocol Layer (Weeks 3-4)

### Objective
Build the foundational ATProto layer: XRPC client, identity resolution, repository operations, and session management.

### Architecture Overview

```
ProtoRune (main API)
    ↓
ProtoRune.Client (HTTP wrapper)
    ↓
ProtoRune.XRPC (XRPC protocol)
    ↓
ATProto Layer:
  - ProtoRune.ATProto.Identity (DID/handle resolution)
  - ProtoRune.ATProto.Repo (repository CRUD)
  - ProtoRune.ATProto.Server (server methods)
```

### Core Concepts

**1. Client**: HTTP client wrapper with base URL and configuration
**2. Session**: Authenticated session with access/refresh JWT tokens
**3. XRPC**: Remote procedure call protocol over HTTP
**4. Identity**: DID (Decentralized ID) and handle resolution
**5. Repository**: User data storage (collections of records)

### Simple API Examples

#### Client Creation
```elixir
# Create client pointing to a PDS (Personal Data Server)
{:ok, client} = ProtoRune.new("https://bsky.social")

# With custom options
{:ok, client} = ProtoRune.new("https://bsky.social",
  timeout: 30_000,
  user_agent: "MyApp/1.0.0"
)
```

#### Authentication
```elixir
# Login with handle and app password
{:ok, session} = ProtoRune.login(
  client,
  "alice.bsky.social",
  "abcd-1234-efgh-5678"
)

# Session contains:
# - access_jwt (short-lived)
# - refresh_jwt (long-lived)
# - did (your decentralized ID)
# - handle
# - pds_url (your data server)

# Resume from stored tokens
{:ok, session} = ProtoRune.resume_session(
  client,
  access_jwt: "eyJ...",
  refresh_jwt: "eyJ..."
)

# Session automatically refreshes access token when needed
```

#### Identity Resolution
```elixir
# Resolve handle to DID
{:ok, did} = ProtoRune.ATProto.Identity.resolve_handle(
  client,
  "alice.bsky.social"
)
# => "did:plc:abc123xyz"

# Resolve DID to document
{:ok, doc} = ProtoRune.ATProto.Identity.resolve_did(
  client,
  "did:plc:abc123xyz"
)
# => %{service: [...], verification_method: [...]}

# Get PDS endpoint from DID
{:ok, pds_url} = ProtoRune.ATProto.Identity.get_pds_endpoint(
  client,
  "did:plc:abc123xyz"
)
# => "https://morel.us-east.host.bsky.network"
```

#### Repository Operations (Low-Level)
```elixir
# Create a record
{:ok, result} = ProtoRune.ATProto.Repo.create_record(
  session,
  collection: "app.bsky.feed.post",
  record: %{
    "$type" => "app.bsky.feed.post",
    "text" => "Hello ATProto!",
    "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
  }
)
# => %{uri: "at://did:plc:abc/app.bsky.feed.post/3k...", cid: "bafy..."}

# Get a record
{:ok, record} = ProtoRune.ATProto.Repo.get_record(
  session,
  repo: session.did,  # or another user's DID
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
)

# Update a record
{:ok, result} = ProtoRune.ATProto.Repo.put_record(
  session,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz...",
  record: updated_data
)

# Delete a record
:ok = ProtoRune.ATProto.Repo.delete_record(
  session,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
)

# List records in a collection
{:ok, %{records: records, cursor: cursor}} =
  ProtoRune.ATProto.Repo.list_records(
    session,
    collection: "app.bsky.feed.post",
    limit: 50
  )
```

#### Generic XRPC Calls
```elixir
# For procedures not yet wrapped in high-level API
{:ok, response} = ProtoRune.XRPC.call(
  session,
  method: :get,  # or :post
  nsid: "app.bsky.feed.getTimeline",
  params: %{limit: 20},
  body: nil
)

# Response is automatically parsed and validated if schema exists
```

### Key Design Decisions

**Q: Why explicit session passing?**
- **Functional style**: No hidden global state, easy to test, explicit dependencies
- **Multi-account support**: Can manage multiple sessions simultaneously
- **OTP friendly**: Sessions can be stored in GenServer state

**Q: How are errors handled?**
- **Tagged tuples**: `{:ok, result}` or `{:error, reason}`
- **Structured errors**: `%ProtoRune.Error{type: :rate_limit, message: "...", details: %{}}`
- **Error types**: `:network`, `:auth`, `:rate_limit`, `:validation`, `:not_found`, `:server`

**Q: How does token refresh work?**
- Automatic on 401 response
- Uses refresh_jwt to get new access_jwt
- Updates session struct
- Retries original request

**Q: How is caching handled?**
- Identity resolution caches DID↔handle mappings (1 hour TTL)
- Optional: User can provide their own cache via behaviour

### Success Criteria
- [ ] Can create client and login
- [ ] Can resolve DIDs and handles
- [ ] Can create, read, update, delete records
- [ ] Token refresh works automatically
- [ ] All errors are properly typed and handled
- [ ] Documentation shows both high and low level usage

---

## Phase 3: Bluesky High-Level API (Weeks 5-6)

### Objective
Provide ergonomic, task-focused functions for common Bluesky operations. Users should accomplish tasks in 1-2 lines without understanding ATProto internals.

### Core Concept
The `ProtoRune.Bsky` namespace provides convenience wrappers around XRPC calls and repository operations, handling the complexity of record creation, URI formatting, and data validation.

### Module Organization

```
ProtoRune.Bsky
├── Feed       - Posts, timelines, threads, likes, reposts
├── Graph      - Follows, blocks, mutes, lists
├── Actor      - Profiles, preferences, search
└── Notification - Notifications, unread counts
```

### Simple API Examples

#### Posting

```elixir
# Simple text post
{:ok, post} = ProtoRune.Bsky.post(session, "Hello Bluesky!")

# Post with options
{:ok, post} = ProtoRune.Bsky.post(
  session,
  "Check out this cool project!",
  langs: ["en", "pt"],
  tags: ["elixir", "atproto"]
)

# Reply to a post
{:ok, reply} = ProtoRune.Bsky.post(
  session,
  "Great point!",
  reply_to: "at://did:plc:xyz/app.bsky.feed.post/3k..."
)

# Post with rich text (covered in detail below)
{:ok, rt} =
  ProtoRune.RichText.new()
  |> ProtoRune.RichText.text("Hello ")
  |> ProtoRune.RichText.mention("alice.bsky.social")
  |> ProtoRune.RichText.build()

{:ok, post} = ProtoRune.Bsky.post(session, rt)

# Delete a post
:ok = ProtoRune.Bsky.delete_post(session, post.uri)
```

#### Social Interactions

```elixir
# Like a post
{:ok, like} = ProtoRune.Bsky.like(
  session,
  uri: post.uri,
  cid: post.cid
)

# Unlike
:ok = ProtoRune.Bsky.unlike(session, like.uri)

# Repost
{:ok, repost} = ProtoRune.Bsky.repost(
  session,
  uri: post.uri,
  cid: post.cid
)

# Unrepost
:ok = ProtoRune.Bsky.unrepost(session, repost.uri)
```

#### Following & Blocking

```elixir
# Follow someone
{:ok, follow} = ProtoRune.Bsky.follow(session, "alice.bsky.social")

# Unfollow
:ok = ProtoRune.Bsky.unfollow(session, follow.uri)

# Block someone
{:ok, block} = ProtoRune.Bsky.block(session, "spammer.bsky.social")

# Unblock
:ok = ProtoRune.Bsky.unblock(session, block.uri)

# Mute (client-side only, not stored on server)
{:ok, mute} = ProtoRune.Bsky.mute(session, "noisy.bsky.social")

# Unmute
:ok = ProtoRune.Bsky.unmute(session, "noisy.bsky.social")
```

#### Reading Content

```elixir
# Get your timeline
{:ok, %{feed: posts, cursor: cursor}} =
  ProtoRune.Bsky.get_timeline(session, limit: 20)

# Paginate through timeline
{:ok, %{feed: more_posts, cursor: next_cursor}} =
  ProtoRune.Bsky.get_timeline(session, limit: 20, cursor: cursor)

# Get a specific post with thread context
{:ok, thread} = ProtoRune.Bsky.get_post_thread(
  session,
  "at://did:plc:xyz/app.bsky.feed.post/3k..."
)

# Get multiple posts at once
{:ok, posts} = ProtoRune.Bsky.get_posts(session, [
  "at://did:plc:abc/app.bsky.feed.post/3k1...",
  "at://did:plc:xyz/app.bsky.feed.post/3k2..."
])

# Search posts
{:ok, %{posts: results, cursor: cursor}} =
  ProtoRune.Bsky.search_posts(
    session,
    query: "elixir lang:en",
    limit: 25
  )
```

#### Profiles

```elixir
# Get a profile
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "alice.bsky.social")
# => %{did: "...", handle: "...", display_name: "...", description: "...",
#      avatar: "...", follower_count: 123, follows_count: 456}

# Get multiple profiles
{:ok, profiles} = ProtoRune.Bsky.get_profiles(session, [
  "alice.bsky.social",
  "bob.bsky.social"
])

# Update your profile
{:ok, profile} = ProtoRune.Bsky.update_profile(
  session,
  display_name: "Alice Wonder",
  description: "Elixir developer | ATProto enthusiast",
  avatar: avatar_blob  # from upload_blob
)

# Search for users
{:ok, %{actors: users, cursor: cursor}} =
  ProtoRune.Bsky.search_actors(session, query: "elixir", limit: 20)
```

#### Notifications

```elixir
# List notifications
{:ok, %{notifications: notifs, cursor: cursor}} =
  ProtoRune.Bsky.list_notifications(session, limit: 30)

# Each notification has:
# - uri: notification URI
# - cid: content ID
# - author: who triggered it
# - reason: "like", "repost", "follow", "mention", "reply", "quote"
# - record: the actual content
# - is_read: boolean
# - indexed_at: timestamp

# Get unread count
{:ok, %{count: unread}} = ProtoRune.Bsky.get_unread_count(session)

# Mark as seen
:ok = ProtoRune.Bsky.update_seen(session, seen_at: DateTime.utc_now())
```

#### Blob Upload (Images, etc.)

```elixir
# Upload an image
{:ok, blob} = ProtoRune.Bsky.upload_blob(
  session,
  File.read!("photo.jpg"),
  mime_type: "image/jpeg"
)

# Use in post
{:ok, post} = ProtoRune.Bsky.post(
  session,
  "Check out this photo!",
  images: [
    %{
      alt: "A beautiful sunset",
      blob: blob,
      aspect_ratio: %{width: 1600, height: 900}
    }
  ]
)

# Embed external link
{:ok, post} = ProtoRune.Bsky.post(
  session,
  "Interesting article!",
  external: %{
    uri: "https://example.com/article",
    title: "How ATProto Works",
    description: "Deep dive into ATProto's architecture",
    thumb: thumbnail_blob  # optional
  }
)
```

### Rich Text Builder

Rich text is complex because it requires calculating byte offsets for facets (mentions, links, hashtags). The builder handles this automatically.

```elixir
alias ProtoRune.RichText

# Build rich text with mentions, links, and hashtags
{:ok, rt} =
  RichText.new()
  |> RichText.text("Hey ")
  |> RichText.mention("alice.bsky.social")  # Automatically resolves handle to DID
  |> RichText.text(", check out ")
  |> RichText.link("this project", "https://github.com/zoedsoupe/proto_rune")
  |> RichText.text("! ")
  |> RichText.hashtag("elixir")
  |> RichText.hashtag("atproto")
  |> RichText.build()

# Use in post
{:ok, post} = ProtoRune.Bsky.post(session, rt)

# Extract plain text if needed
plain = RichText.to_plain_text(rt)
# => "Hey @alice.bsky.social, check out this project! #elixir #atproto"

# Get facets for inspection
facets = RichText.facets(rt)
# => [%{index: %{byteStart: 4, byteEnd: 22}, features: [...]}, ...]
```

**How it works internally:**
1. Each operation calculates byte offset (not character offset!)
2. Facets are accumulated as text is built
3. `build/1` validates the final structure
4. Mention handles are resolved to DIDs (with caching)

### Key Design Decisions

**Q: Why separate modules (Feed, Graph, Actor)?**
- **Domain clarity**: Groups related operations logically
- **Namespace management**: Prevents name collisions
- **ATProto alignment**: Mirrors lexicon organization (app.bsky.feed.*, app.bsky.graph.*)

**Q: How do we handle AT-URIs?**
- Accept both full URIs and short forms
- `"at://did:plc:xyz/app.bsky.feed.post/3k..."` (full)
- Module provides helper: `ProtoRune.ATProto.URI.parse/1`

**Q: What about pagination?**
- All list operations return `{:ok, %{items: [...], cursor: cursor}}`
- Pass cursor to next call: `get_timeline(session, cursor: cursor)`
- `nil` cursor means no more results

**Q: How are validation errors surfaced?**
- Use generated Peri schemas to validate before sending
- Return `{:error, %ProtoRune.ValidationError{...}}` with detailed field errors
- Example: `{:error, %{text: ["is required"], created_at: ["must be datetime"]}}`

### Success Criteria
- [ ] Can post, like, repost, follow in 1-2 lines
- [ ] Rich text builder works for complex mentions/links
- [ ] All pagination works consistently
- [ ] Profile updates work with blob uploads
- [ ] Notification listing and marking seen works
- [ ] Documentation has clear examples for every function

---

## Phase 4: Bot Framework (Weeks 7-8)

### Objective
Enable developers to build event-driven bots that respond to mentions, likes, follows, and other notifications using OTP principles.

### Core Concept
A bot is a GenServer that periodically polls for notifications, converts them to events, and dispatches to user-defined handlers. The framework handles authentication, error recovery, rate limiting, and supervision.

### Simple API Examples

#### Basic Bot

```elixir
defmodule GreeterBot do
  use ProtoRune.Bot,
    handle: "greeter.bsky.social",
    password: System.get_env("BOT_PASSWORD"),
    strategy: :polling,
    interval: 30_000  # Check every 30 seconds

  require Logger

  # Handle mentions
  @impl true
  def handle_event({:mention, notification}, state) do
    Logger.info("Got mentioned by #{notification.author.handle}")

    # Reply to the mention
    {:ok, _reply} = ProtoRune.Bsky.post(
      state.session,
      "👋 Hi #{notification.author.handle}! Thanks for the mention!",
      reply_to: notification.uri
    )

    {:ok, state}
  end

  # Handle new followers
  @impl true
  def handle_event({:follow, notification}, state) do
    Logger.info("New follower: #{notification.author.handle}")

    # Follow them back
    {:ok, _follow} = ProtoRune.Bsky.follow(
      state.session,
      notification.author.did
    )

    {:ok, state}
  end

  # Handle likes on your posts
  @impl true
  def handle_event({:like, notification}, state) do
    Logger.info("#{notification.author.handle} liked your post")
    {:ok, state}
  end

  # Catch-all for unhandled events
  @impl true
  def handle_event(_event, state) do
    {:ok, state}
  end
end

# Start the bot
{:ok, pid} = GreeterBot.start_link()

# Or add to supervision tree
children = [
  GreeterBot
]
Supervisor.start_link(children, strategy: :one_for_one)
```

#### Advanced Bot with State

```elixir
defmodule CounterBot do
  use ProtoRune.Bot,
    handle: "counter.bsky.social",
    password: System.get_env("BOT_PASSWORD"),
    strategy: :polling,
    interval: 60_000

  # Initialize custom state
  @impl true
  def init(state) do
    # Add custom fields to state
    custom_state = Map.merge(state, %{
      mention_count: 0,
      like_count: 0,
      start_time: DateTime.utc_now()
    })

    {:ok, custom_state}
  end

  @impl true
  def handle_event({:mention, notification}, state) do
    new_count = state.mention_count + 1

    # Every 10 mentions, post stats
    if rem(new_count, 10) == 0 do
      uptime = DateTime.diff(DateTime.utc_now(), state.start_time, :hour)

      ProtoRune.Bsky.post(
        state.session,
        """
        📊 Bot Stats:
        • Mentions: #{new_count}
        • Likes: #{state.like_count}
        • Uptime: #{uptime}h
        """
      )
    end

    {:ok, %{state | mention_count: new_count}}
  end

  @impl true
  def handle_event({:like, _notification}, state) do
    {:ok, %{state | like_count: state.like_count + 1}}
  end

  @impl true
  def handle_event(_event, state), do: {:ok, state}
end
```

#### Bot with Scheduled Posts

```elixir
defmodule DailyQuoteBot do
  use ProtoRune.Bot,
    handle: "quotes.bsky.social",
    password: System.get_env("BOT_PASSWORD"),
    strategy: :polling,
    interval: 60_000

  # Schedule daily post
  @impl true
  def init(state) do
    schedule_daily_post()
    {:ok, state}
  end

  # Handle scheduled message
  @impl true
  def handle_info(:daily_post, state) do
    quote = fetch_random_quote()  # Your implementation

    ProtoRune.Bsky.post(state.session, """
    💭 Quote of the day:

    "#{quote.text}"

    — #{quote.author}
    """)

    schedule_daily_post()  # Schedule next one
    {:noreply, state}
  end

  @impl true
  def handle_event(_event, state), do: {:ok, state}

  defp schedule_daily_post do
    # Calculate time until next 9am UTC
    now = DateTime.utc_now()
    tomorrow_9am = # ... calculate next 9am
    delay = DateTime.diff(tomorrow_9am, now, :millisecond)

    Process.send_after(self(), :daily_post, delay)
  end

  defp fetch_random_quote do
    # Your quote fetching logic
  end
end
```

#### Bot Error Handling

```elixir
defmodule ResilientBot do
  use ProtoRune.Bot,
    handle: "resilient.bsky.social",
    password: System.get_env("BOT_PASSWORD"),
    strategy: :polling,
    interval: 30_000,
    # Bot-specific options
    max_retries: 3,
    backoff: :exponential

  require Logger

  @impl true
  def handle_event({:mention, notification}, state) do
    case process_mention(notification, state) do
      {:ok, result} ->
        {:ok, state}

      {:error, :rate_limit} ->
        Logger.warn("Rate limited, will retry")
        # Framework automatically backs off
        {:retry, state}

      {:error, reason} ->
        Logger.error("Failed to process mention: #{inspect(reason)}")
        # Continue processing other events
        {:ok, state}
    end
  end

  @impl true
  def handle_event(_event, state), do: {:ok, state}

  defp process_mention(notification, state) do
    # Your processing logic that might fail
    ProtoRune.Bsky.post(
      state.session,
      "Reply to #{notification.author.handle}",
      reply_to: notification.uri
    )
  end
end
```

### Event Types

All notification reasons are converted to event tuples:

```elixir
{:mention, notification}   # Someone mentioned you
{:reply, notification}     # Someone replied to your post
{:quote, notification}     # Someone quoted your post
{:like, notification}      # Someone liked your post
{:repost, notification}    # Someone reposted
{:follow, notification}    # Someone followed you
{:unknown, notification}   # Unknown notification type
```

Each notification contains:
- `uri` - notification URI
- `cid` - content ID
- `author` - who triggered it (handle, did, display_name, avatar)
- `reason` - reason string
- `record` - the actual content
- `is_read` - read status
- `indexed_at` - timestamp

### Bot Lifecycle

```elixir
# Bot automatically:
# 1. Creates client on startup
# 2. Logs in with credentials
# 3. Starts polling loop
# 4. Fetches notifications
# 5. Converts to events
# 6. Calls your handlers
# 7. Updates last_seen cursor
# 8. Waits for next interval
# 9. Repeats

# On error:
# 1. Logs error
# 2. Backs off if rate limited
# 3. Retries with exponential backoff
# 4. Supervisor restarts if crash
# 5. State can be persisted/recovered
```

### Supervision

```elixir
# Multiple bots in one app
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      GreeterBot,
      CounterBot,
      DailyQuoteBot,
      # Other workers
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# Each bot has its own supervisor internally:
# BotSupervisor
#  ├─ BotWorker (your GenServer)
#  └─ PollingWorker (fetches notifications)
```

### Telemetry Events

```elixir
# Bots emit telemetry for observability
:telemetry.attach_many(
  "bot-metrics",
  [
    [:proto_rune, :bot, :event, :start],
    [:proto_rune, :bot, :event, :stop],
    [:proto_rune, :bot, :event, :exception],
    [:proto_rune, :bot, :poll, :start],
    [:proto_rune, :bot, :poll, :stop]
  ],
  &handle_telemetry/4,
  nil
)

# Example metrics:
# - Event processing duration
# - Poll success/failure rate
# - Rate limit hits
# - Event type distribution
```

### Key Design Decisions

**Q: Why polling instead of webhook?**
- **Simpler**: No public endpoint needed
- **ATProto native**: Bluesky doesn't have webhooks yet
- **Good enough**: 30s polling is fine for most bots
- **Future**: Will add Firehose strategy for real-time needs

**Q: How does rate limiting work?**
- Framework tracks requests per minute
- Automatically backs off when hitting limits
- Returns `{:retry, state}` from handler to retry later
- Exponential backoff for persistent errors

**Q: How is state persisted?**
- Optional: Implement `persist_state/1` callback
- Framework calls it periodically
- On restart, `init/1` receives persisted state
- Example: Store in ETS, database, or file

**Q: Can I test bots without real API calls?**
- Yes: Provide mock session in tests
- Use `ProtoRune.Bot.inject_event/2` to simulate events
- Mock XRPC layer with Mox or similar

### Success Criteria
- [ ] Can create a working bot in <20 lines
- [ ] Bot survives crashes via supervision
- [ ] Rate limiting works automatically
- [ ] Custom state management works
- [ ] Telemetry provides observability
- [ ] Documentation has 5+ bot examples

---

## Phase 5: Documentation & Polish (Weeks 9-10)

### Objective
Create comprehensive documentation, examples, and polish the developer experience to make ProtoRune production-ready.

### Documentation Structure

```
docs/
├── guides/
│   ├── getting-started.md
│   ├── authentication.md
│   ├── posting-content.md
│   ├── rich-text.md
│   ├── bot-development.md
│   ├── repository-operations.md (advanced)
│   ├── lexicon-generation.md (advanced)
│   └── error-handling.md
├── examples/
│   ├── simple_post.exs
│   ├── rich_text_post.exs
│   ├── greeter_bot.ex
│   ├── daily_poster_bot.ex
│   ├── notification_monitor.ex
│   └── custom_feed.ex (future)
└── api-reference/  (auto-generated by ExDoc)
```

### README Improvements

Update README.md to include:
- Clear feature matrix
- Quick start (3 examples in 30 seconds)
- Comparison with other libraries
- Installation instructions
- Link to full documentation
- Community/support links
- Contributor guidelines

### Example Applications

Create working examples that users can run:

**1. Simple CLI Poster**
```bash
# examples/cli_post.exs
# Usage: elixir examples/cli_post.exs "Hello Bluesky!"
```

**2. Greeter Bot**
```bash
# examples/greeter_bot/
# Full OTP app that replies to mentions
mix deps.get && mix run --no-halt
```

**3. Feed Monitor**
```bash
# examples/feed_monitor/
# Monitors timeline and logs statistics
```

**4. Image Poster**
```bash
# examples/image_post.exs
# Posts an image with caption and alt text
```

### Testing Infrastructure

**Unit Tests**
- All modules have >80% coverage
- Use mocks for external API calls
- Test error conditions

**Integration Tests**
- Hit real API with test account
- Marked with `@tag :integration`
- Run in CI with credentials

**Property Tests**
- Use StreamData for generated schemas
- Ensure validation works for all inputs

### Developer Experience Polish

**1. Helpful Error Messages**
```elixir
# Bad:
{:error, :invalid}

# Good:
{:error, %ProtoRune.ValidationError{
  message: "Post validation failed",
  errors: [
    text: "is required and must be a string",
    created_at: "must be a valid datetime"
  ]
}}
```

**2. Type Specs**
- Every public function has `@spec`
- Run Dialyzer in CI
- Generate type documentation

**3. Inline Documentation**
```elixir
@doc """
Posts a message to Bluesky.

## Parameters

  * `session` - Authenticated session from `ProtoRune.login/3`
  * `content` - Text or `RichText` struct
  * `opts` - Optional parameters:
    * `:reply_to` - AT-URI of post to reply to
    * `:langs` - List of language codes (default: `["en"]`)
    * `:tags` - List of tags for discovery

## Returns

  * `{:ok, post}` - Post struct with URI and CID
  * `{:error, reason}` - Error details

## Examples

    {:ok, post} = ProtoRune.Bsky.post(session, "Hello!")

    {:ok, reply} = ProtoRune.Bsky.post(
      session,
      "Great point!",
      reply_to: post.uri
    )
"""
```

**4. Logging**
- Structured logging with metadata
- Log levels for debugging
- Quiet by default

**5. Configuration**
```elixir
# config/config.exs
config :proto_rune,
  default_pds: "https://bsky.social",
  timeout: 30_000,
  identity_cache_ttl: 3600,
  log_level: :info
```

### Performance Validation

**Benchmarks**
- Create benchmarks for common operations
- Post creation
- Timeline fetching
- Identity resolution (with/without cache)

**Memory Usage**
- Profile memory for bot running 24h
- Ensure no leaks in polling loop

**Concurrency**
- Test multiple bots running simultaneously
- Verify no race conditions in shared resources

### Release Checklist

Before v0.2.0:
- [ ] All Phase 1-4 features implemented
- [ ] Test coverage >80%
- [ ] All examples run successfully
- [ ] Documentation complete
- [ ] CHANGELOG.md updated
- [ ] Version bumped in mix.exs
- [ ] Hex package metadata complete
- [ ] GitHub releases configured
- [ ] CI/CD passing
- [ ] Dogfood: Run a real bot for 1 week

---

## Success Metrics

The MVP is successful when:

1. **Developer Experience**
   - A new user can post in <5 minutes
   - A new user can deploy a bot in <30 minutes
   - Documentation answers 90% of questions

2. **Technical Quality**
   - All generated lexicons compile without errors
   - Test coverage >80%
   - No memory leaks in 24h bot runs
   - Dialyzer reports no errors

3. **Real-World Usage**
   - At least 3 example bots running in production
   - Can handle 1000+ notifications without issues
   - Sessions refresh automatically
   - Bots survive network interruptions

4. **Community**
   - 5+ GitHub stars
   - 3+ external contributors
   - Package published to Hex
   - Listed on ATProto ecosystem page

---

## Future Phases (Post-MVP)

These are explicitly out of scope for v0.2.0 but good to keep in mind:

### Phase 6: OAuth (v0.3.0)
- Full OAuth client implementation
- PKCE support
- Token storage helpers
- Web flow examples

### Phase 7: Firehose (v0.3.0)
- WebSocket connection to firehose
- CAR file parsing
- Event filtering
- High-throughput bot strategy

### Phase 8: Advanced Features (v0.4.0)
- Jetstream support
- Feed generator SDK
- Ozone (moderation) integration
- Custom lexicons support
- Merkle Search Tree implementation

---

## Open Questions & Decisions Needed

### 1. Lexicon Version Management
**Question**: How do users pin lexicon versions?

**Options**:
- A: Commit generated code, manual regeneration
- B: Generate at compile-time, version in submodule
- C: Fetch lexicons from CDN at compile-time

**Recommendation**: Option A for MVP (simplest, most reliable)

### 2. Multi-Account Bots
**Question**: Should bot framework support multiple accounts?

**Options**:
- A: One bot = one account (simple)
- B: Pass account config as list (complex)

**Recommendation**: Option A for MVP, Option B for v0.3.0

### 3. Rich Text Parsing (Markdown-like)
**Question**: Should we support markdown-style rich text?

```elixir
# Instead of builder:
RichText.parse("Hey @alice check [this](https://example.com) #elixir")
```

**Recommendation**: Post-MVP (nice-to-have, not essential)

### 4. Ecto Integration
**Question**: Should we provide optional Ecto schemas?

**Options**:
- A: Peri only (simpler)
- B: Generate both Peri and Ecto (complex)
- C: Provide Peri → Ecto conversion helpers

**Recommendation**: Option C for MVP (best of both worlds)

### 5. Caching Strategy
**Question**: How should identity resolution caching work?

**Options**:
- A: In-memory cache (simple, process-based)
- B: ETS cache (shared across processes)
- C: Pluggable cache behaviour

**Recommendation**: Option B with fallback to A

---

## Appendix: ATProto Concepts

For reference, core ATProto concepts and how they map to ProtoRune:

### Identity Layer
- **DID**: Decentralized Identifier (e.g., `did:plc:abc123`)
  - ProtoRune: `ProtoRune.ATProto.Identity.resolve_did/2`
- **Handle**: Human-readable name (e.g., `alice.bsky.social`)
  - ProtoRune: `ProtoRune.ATProto.Identity.resolve_handle/2`
- **Resolution**: DID ↔ Handle mapping
  - ProtoRune: Cached automatically

### Repository Layer
- **Repository**: User's data storage
  - ProtoRune: `ProtoRune.ATProto.Repo.*`
- **Collection**: Type of records (e.g., `app.bsky.feed.post`)
  - ProtoRune: Passed as string parameter
- **Record**: Individual data item
  - ProtoRune: Map validated by Peri schema
- **AT-URI**: Address to a record (e.g., `at://did/collection/rkey`)
  - ProtoRune: Returned from create/get operations
- **CID**: Content ID (hash of record)
  - ProtoRune: Returned with records for versioning

### Lexicon Layer
- **Lexicon**: Schema definition in JSON
  - ProtoRune: Compiled to Peri schemas
- **NSID**: Namespaced ID (e.g., `app.bsky.feed.post`)
  - ProtoRune: Module name (`ProtoRune.Lexicon.App.Bsky.Feed.Post`)
- **Ref**: Reference to another lexicon
  - ProtoRune: Module reference
- **Union**: One of several types
  - ProtoRune: `{:oneof, [types]}`

### Application Layer (Bluesky)
- **Post**: `app.bsky.feed.post`
  - ProtoRune: `ProtoRune.Bsky.post/2`
- **Like**: `app.bsky.feed.like`
  - ProtoRune: `ProtoRune.Bsky.like/2`
- **Follow**: `app.bsky.graph.follow`
  - ProtoRune: `ProtoRune.Bsky.follow/2`
- **Profile**: `app.bsky.actor.profile`
  - ProtoRune: `ProtoRune.Bsky.get_profile/2`

### XRPC Layer
- **Query**: GET request that returns data
  - ProtoRune: `ProtoRune.XRPC.call(session, :get, nsid, params)`
- **Procedure**: POST request that modifies data
  - ProtoRune: `ProtoRune.XRPC.call(session, :post, nsid, body)`

---

## Final Notes

### What Makes This Roadmap Different

1. **ATProto-First**: Every decision respects ATProto's architecture
2. **Simplicity**: Lexicon generation uses simplest viable approach
3. **User-Focused**: API examples show actual usage, not implementation
4. **OTP-Native**: Leverages Elixir/OTP for reliability
5. **Incremental**: Each phase builds on previous, can pause anywhere

### How to Use This Roadmap

1. **Read fully** to understand the vision
2. **Start with Phase 1** (lexicon generation is foundation)
3. **Validate each phase** with working examples before moving on
4. **Reference often** when making design decisions
5. **Update as needed** when discovering better approaches

### Getting Help

If you get stuck on any phase:
1. Review the RFC (architecture) and Analysis (implementation details)
2. Check reference implementations (jacquard, atcute, peri)
3. Read ATProto specs at https://atproto.com
4. Ask in Bluesky ATProto Discord

---

**Document Version**: 1.0
**Created**: 2025-10-20
**Status**: Ready for Implementation
**Next Step**: Begin Phase 1 - Lexicon Code Generation
