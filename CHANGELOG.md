# Changelog

## [0.6.0](https://github.com/zoedsoupe/proto_rune/compare/v0.5.3...v0.6.0) (2026-09-22)


### Features

* **bsky:** feed generator SDK (skeleton/describe builders, feed publishing) ([db46484](https://github.com/zoedsoupe/proto_rune/commit/db46484e9b4a2b13ff6a49cd33a1a619292ecca8))
* **bsky:** media embeds for posts (images, external, quote, recordWithMedia) ([7c283b3](https://github.com/zoedsoupe/proto_rune/commit/7c283b38f0b8f8635054af1f9d45b95084c3d794))
* **cbor:** add canonical DAG-CBOR encoding ([aebc218](https://github.com/zoedsoupe/proto_rune/commit/aebc218787c16a3c5cb7062a1905f1c348f991dc))
* **chat:** Chat.Convo module with full convo coverage ([592d8fc](https://github.com/zoedsoupe/proto_rune/commit/592d8fcbae9e451abf693f02ae680db448c8ae56))
* **http:** per-request adapter and http options ([0e12288](https://github.com/zoedsoupe/proto_rune/commit/0e1228848de95511ee5ad64939f2e7a5f0b9610e))
* **identity:** implement verify_signature/3 ([2ba2922](https://github.com/zoedsoupe/proto_rune/commit/2ba2922879be6493c278225917577a3f600026cd))
* **repo:** applyWrites and string-only collection NSIDs ([34e3c06](https://github.com/zoedsoupe/proto_rune/commit/34e3c06dafef825018824de97f9e4e40d17a8402))
* **session:** generic SessionManager, JWT expiry on sessions ([81da7dc](https://github.com/zoedsoupe/proto_rune/commit/81da7dc0ea45fdec66079ad099e55709135f1b7f))
* **sync:** add MST inclusion proofs for partial trees and firehose ops ([eea7d2d](https://github.com/zoedsoupe/proto_rune/commit/eea7d2dd1e093094a76e4843605076988115898d))
* **sync:** verify repo checkouts against commit signature and block CIDs ([e4ab00c](https://github.com/zoedsoupe/proto_rune/commit/e4ab00cd96e1cef4e72d105ca5c9249ac6576f3b))
* **xrpc:** unified request runtime and cursor pagination ([d80d49a](https://github.com/zoedsoupe/proto_rune/commit/d80d49a95bcf3cf7c9a8bf2f3c28a2821e85eec3))


### Bug Fixes

* **bot:** per-notification timestamp filter, dead message path removed ([65a912c](https://github.com/zoedsoupe/proto_rune/commit/65a912c06dda22b37020f0c9e19abc5e226c4e6d))
* **bot:** require credential callbacks, align payload docs ([3db6b17](https://github.com/zoedsoupe/proto_rune/commit/3db6b17295a0cc3fcfa1a16bbeb01aa3f061ff0f))
* credo ([33f0496](https://github.com/zoedsoupe/proto_rune/commit/33f0496993e05e26509000b9e16a83c8483e3dcb))
* format ([c35abdf](https://github.com/zoedsoupe/proto_rune/commit/c35abdfd6e6f1658c8dd79c34f433878be4319ce))
* **identity:** accept string keys in DID doc signing key lookup ([fb79a4e](https://github.com/zoedsoupe/proto_rune/commit/fb79a4e074a7e26da9f9535574108cffe33ca8f3))
* **session:** polymorphic refresh and behaviour-routed repo writes ([d216cc1](https://github.com/zoedsoupe/proto_rune/commit/d216cc10d157410c7534eb33764524b720f2313f))
* **xrpc:** public Error struct with atom reasons and retry_after ([ce5b960](https://github.com/zoedsoupe/proto_rune/commit/ce5b960727d55c4933bf8cd1105b1234933a65b2))
* **xrpc:** stop interning server-controlled response keys ([e6a2963](https://github.com/zoedsoupe/proto_rune/commit/e6a2963474875c92dca43910531a8899c4d6a8d8))


### Documentation

* fold getting started guide into readme, trim session recipe ([ea10dd8](https://github.com/zoedsoupe/proto_rune/commit/ea10dd8e81df65f0af5e3264cf5a0b3d8924daf4))
* rewrite readme around building atproto apps ([5be1225](https://github.com/zoedsoupe/proto_rune/commit/5be12258a971b0845a69e15c23afbe4c356020f7))
* sync guides with unified session and error API ([ba3700e](https://github.com/zoedsoupe/proto_rune/commit/ba3700e7c8133e8c0c225185580ca38d8a083263))
* sync roadmap with 0.5.x reality, changelog for embeds/verification/feedgen ([5244e96](https://github.com/zoedsoupe/proto_rune/commit/5244e96afdbd63566f7ffee829b4e22be4a2175c))


### Miscellaneous Chores

* apply mix format ([7d47c12](https://github.com/zoedsoupe/proto_rune/commit/7d47c12a068f68d5ef9b19f78f9a488c52b79269))
* release please mark ([4db2d2c](https://github.com/zoedsoupe/proto_rune/commit/4db2d2cb809b98bc2f16acd9fecb239ea8f04e0d))
* remove unused ecto dep, ignore crash dumps ([43db241](https://github.com/zoedsoupe/proto_rune/commit/43db24178b2ade9e846cf37d0907e53f2d96e880))
* simplify docs ([6ea51b0](https://github.com/zoedsoupe/proto_rune/commit/6ea51b0a290a853ca5dc5ff06df01c1642cc8b0a))


### Code Refactoring

* **atproto:** generalize parse_at_uri/1 ([db6c7ee](https://github.com/zoedsoupe/proto_rune/commit/db6c7ee01343f2b2f6d0be2775870c57cb56c34a))
* **bsky:** consolidate record deletes, drop langs default ([1eca6d5](https://github.com/zoedsoupe/proto_rune/commit/1eca6d5acbe4f48dbe46bdc40eeb34fcf6bf62fa))
* **bsky:** expose generated endpoint modules, normalize helper returns ([a0a75ad](https://github.com/zoedsoupe/proto_rune/commit/a0a75ad2df5f78973b34676ba93c3f057da85ac1))
* **config:** merge XRPC.Config into ProtoRune.Config ([495d9d9](https://github.com/zoedsoupe/proto_rune/commit/495d9d9097bf2e43269500aa14b0922c57d6c734))
* **http:** share case-insensitive response header lookup ([aefaff5](https://github.com/zoedsoupe/proto_rune/commit/aefaff5d4e082dd8b130024c1dae90ff6019c2f2))
* **identity:** drop single-implementation behaviour ([50cd91f](https://github.com/zoedsoupe/proto_rune/commit/50cd91fa1788d352caa080ff60b90ba12aa54dd9))
* **streams:** shared WebSocket client for firehose and jetstream ([97ad5b2](https://github.com/zoedsoupe/proto_rune/commit/97ad5b2b8a25e369253ff0c7ddbdc40939618062))
* **xrpc:** thin DSL over the shared runtime ([791f29e](https://github.com/zoedsoupe/proto_rune/commit/791f29e43d6e07680576adda27ef4ee72360cfee))


### Tests

* fix assert_receive timeout ([270ed93](https://github.com/zoedsoupe/proto_rune/commit/270ed938b2d835ca7b8bc1b63f9a96273a90e326))
* **repo:** exercise collection resolution through create_record ([85dbcbf](https://github.com/zoedsoupe/proto_rune/commit/85dbcbfb98f7f60224d7b02cb690327c348b629c))
* stub http through request options instead of app env ([fdfeb16](https://github.com/zoedsoupe/proto_rune/commit/fdfeb1655b85da5e8dce3e0bfecfd0f288cfa182))

## [Unreleased]


### Features

* **sync:** MST inclusion proofs: `MST.prove/3` extracts a minimal partial tree proving a key's inclusion or absence, `MST.verify_proof/3` checks a claim against such a slice, and `MST.verify_ops/3` verifies firehose commit ops against the event's MST root
* **cid:** `CID.from_string/1` parses base32 multibase CID strings
* **bsky:** media embeds on post: `ProtoRune.Bsky.Embed` builders (images, external cards, quotes, recordWithMedia) and `:embed` / `:images` options on `Bsky.post/3`
* **bsky:** feed generator helpers: `ProtoRune.Bsky.FeedGen` (skeleton/describe response builders, generator record) and `Bsky.publish_feed/3`
* **sync:** `Sync.verify_checkout/2` verifies a repo checkout: block integrity against CIDs plus commit signature verification (`ProtoRune.Commit`) against the repo's DID document, for P-256 and secp256k1 signing keys
* **cbor:** `CBOR.encode/1` canonical DAG-CBOR encoding

### Bug Fixes

* **mst:** reconstruct keys with per-node prefix compression (a node's first entry always carries its full key), matching the reference implementation

## [0.5.3](https://github.com/zoedsoupe/proto_rune/compare/v0.5.2...v0.5.3) (2026-08-27)


### Bug Fixes

* gracefully stops session_manager whn invalid_grant ([5e6b95c](https://github.com/zoedsoupe/proto_rune/commit/5e6b95cde343d282ace3ceb7c892611e32d8b70f))


### Miscellaneous Chores

* format ([0be8529](https://github.com/zoedsoupe/proto_rune/commit/0be8529c18427d49f850c209d24cad4940493c74))

## [0.5.2](https://github.com/zoedsoupe/proto_rune/compare/v0.5.1...v0.5.2) (2026-08-20)


### Bug Fixes

* **identity:** handle list-valued content-type headers in handle resolver ([aea4022](https://github.com/zoedsoupe/proto_rune/commit/aea40220b253ab3ad5f4f2855114ed19b6a52de2))

## [0.5.1](https://github.com/zoedsoupe/proto_rune/compare/v0.5.0...v0.5.1) (2026-08-20)


### Bug Fixes

* **oauth:** sign refresh with session dpop key, not client key ([5c83f36](https://github.com/zoedsoupe/proto_rune/commit/5c83f366842aad153c720fee96c71eabf0306b9c))

## [0.5.0](https://github.com/zoedsoupe/proto_rune/compare/v0.4.2...v0.5.0) (2026-08-19)


### Features

* add jetstream consumer with server-side collection filtering ([57f0761](https://github.com/zoedsoupe/proto_rune/commit/57f0761c89f7b7f828a79340b1d0bc891f3d5293))

## [0.4.2](https://github.com/zoedsoupe/proto_rune/compare/v0.4.1...v0.4.2) (2026-08-18)


### Bug Fixes

* **oauth:** decode dpop response bodies before matching errors ([92ae6ba](https://github.com/zoedsoupe/proto_rune/commit/92ae6ba402b4249584267ee0b26108b53b5b293f))
* **oauth:** read dpop nonce from req response header maps ([121647d](https://github.com/zoedsoupe/proto_rune/commit/121647d6934a6b7abe39cabea22850f220261e70))

## [0.4.1](https://github.com/zoedsoupe/proto_rune/compare/v0.4.0...v0.4.1) (2026-08-18)


### Bug Fixes

* **oauth:** decode json bodies in discovery fetch_json ([ab14a09](https://github.com/zoedsoupe/proto_rune/commit/ab14a096e18094ba48e4399b2624f1aef0b35ff3))


### Miscellaneous Chores

* add ex_doc to ci ([b9b0812](https://github.com/zoedsoupe/proto_rune/commit/b9b0812ee261f6fe06dd31a31aa2fc1571bf70ad))

## [0.4.0](https://github.com/zoedsoupe/proto_rune/compare/v0.3.1...v0.4.0) (2026-08-18)


### Features

* **atproto:** accept any collection NSID in record writes ([2e7c31a](https://github.com/zoedsoupe/proto_rune/commit/2e7c31a331d47a93c94303426e71a79da8f5e7c5))
* **atproto:** add com.atproto.sync read endpoints ([e0b15ad](https://github.com/zoedsoupe/proto_rune/commit/e0b15ad5b3032d2fdf1614a1d8eead06238af8de))
* **atproto:** add resolveHandle XRPC query ([572e32b](https://github.com/zoedsoupe/proto_rune/commit/572e32b2f6c8f0b60d566cd0aa7caef3f887c52b))
* **firehose:** add collection prefix filter to Event ([eabb525](https://github.com/zoedsoupe/proto_rune/commit/eabb525210f8cae6fa6531ddb7d17f77fef8f19a))
* **lexicon:** add --path and --output flags to gen task ([e89c91c](https://github.com/zoedsoupe/proto_rune/commit/e89c91c459cb406f53c2543c7e7801d1a5aae613))
* **oauth:** add SessionManager GenServer ([b56a675](https://github.com/zoedsoupe/proto_rune/commit/b56a675b8a33dce381495d8cfd83a56a6e292c49))
* **oauth:** add token revocation ([9a9ed18](https://github.com/zoedsoupe/proto_rune/commit/9a9ed1811ff9ac3fe99b05a7ad2c23d1cf94d719))
* **oauth:** require encryption key for SessionManager persistence ([b2ef12b](https://github.com/zoedsoupe/proto_rune/commit/b2ef12bd05ef162b0ac745ddd9298829a00e4405))
* **xrpc:** DPoP-bound requests via ProtoRune.Session behaviour ([087b017](https://github.com/zoedsoupe/proto_rune/commit/087b017a55399d4e59185fadf7bbdd97cec66380))
* **xrpc:** support binary responses ([cc05037](https://github.com/zoedsoupe/proto_rune/commit/cc05037f33c16bdf28edc5828ecddda5026d1175))
* **xrpc:** support optional authentication in defquery ([d75480b](https://github.com/zoedsoupe/proto_rune/commit/d75480ba04f8714790c706eaac31dd0a4177919d))


### Bug Fixes

* **bluesky:** correct sendInteractions NSID typo ([6667324](https://github.com/zoedsoupe/proto_rune/commit/6667324cc89c12a7eabc7fdcaf7c4c1b87e790e3))
* **xrpc:** read response headers from Req's map shape ([bb46f0f](https://github.com/zoedsoupe/proto_rune/commit/bb46f0f9818954c18b6006c026d7fb2a70e2dbaf))


### Documentation

* add custom lexicons guide ([dde8df0](https://github.com/zoedsoupe/proto_rune/commit/dde8df0f6e081afd8a1255b6aa1c02f7f667d5fd))
* cover OAuth end-to-end in authentication guide ([502789c](https://github.com/zoedsoupe/proto_rune/commit/502789c343ead1190bd8894f0032c295123c9e0f))
* sync ROADMAP with v0.3.0 release and v0.4.0 plan ([e81f792](https://github.com/zoedsoupe/proto_rune/commit/e81f7921d9d6ba0cc989ccfa5f744148fe5fdb48))


### Tests

* add Bypass-based PDS fixture tests ([bb5b39e](https://github.com/zoedsoupe/proto_rune/commit/bb5b39e84dc823798dca663aa92f368df3c008ac))
* replace named-process registration with env-carried pids ([ac01947](https://github.com/zoedsoupe/proto_rune/commit/ac01947dee8ae88d3603877e0fc6b6c1b8089bfb))
* split the compiler paths ([7d4a3db](https://github.com/zoedsoupe/proto_rune/commit/7d4a3db3b6ef3a897a5f71bfbffb5d7ecb239361))

## [0.3.1](https://github.com/zoedsoupe/proto_rune/compare/v0.3.0...v0.3.1) (2026-08-12)


### Bug Fixes

* **bsky:** align post, like and repost with createRecord schemas ([881b0f1](https://github.com/zoedsoupe/proto_rune/commit/881b0f1372c245321ad2c522643d200c90f1e8a0))

## [0.3.0](https://github.com/zoedsoupe/proto_rune/compare/v0.2.0...v0.3.0) (2026-08-12)


### Features

* **atproto:** add OAuth authorization flow with PAR, PKCE and DPoP ([9f26d79](https://github.com/zoedsoupe/proto_rune/commit/9f26d791ddf51ccea8b3221bb9aaf11f76b746bc))
* **bot:** add firehose strategy ([f8d41eb](https://github.com/zoedsoupe/proto_rune/commit/f8d41eb229acd3b8df62ec4e2ca76ffca25ea5c8))
* **bot:** add telemetry events for event processing, polling and rate limits ([e62abe7](https://github.com/zoedsoupe/proto_rune/commit/e62abe75131d8cc1706100070b77459018aa59a4))
* **bsky:** add search and profile update ([33633ba](https://github.com/zoedsoupe/proto_rune/commit/33633ba25da114cc797d09281b2defdf4b0ee863))
* **firehose:** add real-time event stream client ([b699cce](https://github.com/zoedsoupe/proto_rune/commit/b699ccefad692dff10ac99896e4cb6d9e7e59537))
* **http_client:** add rate limiting and exponential backoff retries (closes [#30](https://github.com/zoedsoupe/proto_rune/issues/30)) ([74dc15e](https://github.com/zoedsoupe/proto_rune/commit/74dc15eb6972562a0bd98b2186343e0e0f87be02))
* **security:** add session token encryption and pluggable storage ([#44](https://github.com/zoedsoupe/proto_rune/issues/44)) ([d3f9940](https://github.com/zoedsoupe/proto_rune/commit/d3f994076879f4d8a1563d72651742aa39b5c373))


### Bug Fixes

* **http_client:** omit connect timeout when unset in req adapter ([981145c](https://github.com/zoedsoupe/proto_rune/commit/981145c1b354620c93f12dd32888aca0fe7b27bd))
* **identity:** make cache optional and document supervision ([756766e](https://github.com/zoedsoupe/proto_rune/commit/756766e8b3c491aaaeea217849cbe76a6b0b6978))
* **xrpc:** decode JSON at the client boundary, not in the Req adapter ([3932d9f](https://github.com/zoedsoupe/proto_rune/commit/3932d9fe56b367cac0dbf302fb66216b42f8f912))
* **xrpc:** per-call base_url, drop app-env fallback, normalize service urls ([238f7e4](https://github.com/zoedsoupe/proto_rune/commit/238f7e474b8565daefbaf7f14fae3fe928225b05))
* **xrpc:** recurse case conversion into nested maps ([d462bfc](https://github.com/zoedsoupe/proto_rune/commit/d462bfca2483783bb57f38763da86f990b557550))


### Documentation

* **cheatsheets:** add bluesky usage cheatsheet, drop broken example stubs ([0263d75](https://github.com/zoedsoupe/proto_rune/commit/0263d753a7e66477c252285069c426213525b0a0))


### Miscellaneous Chores

* update .gitignore ([2ec93f3](https://github.com/zoedsoupe/proto_rune/commit/2ec93f385d7250efc72616fb8c846d1b2c8b55bb))

## [0.2.0](https://github.com/zoedsoupe/proto_rune/compare/v0.1.2...v0.2.0) (2026-08-10)


### Features

* atproto admin functions and chat.bsky moderation ([b644b9f](https://github.com/zoedsoupe/proto_rune/commit/b644b9f533f1b2ad43932ac2da71afdb2a92ef05))
* better error handling ([fc0783e](https://github.com/zoedsoupe/proto_rune/commit/fc0783ed53af2454f466990f113d5e2dccbfb9ea))
* bot framework with polling strategy ([f6220cb](https://github.com/zoedsoupe/proto_rune/commit/f6220cbcaae8e86f777aab08ec0bddb2ff6d0bd1))
* complement atproto server namespace ([1c3026b](https://github.com/zoedsoupe/proto_rune/commit/1c3026bdaada35d73129c7adc071fa9978b3b8bb))
* fetch lexicons from atproto official project ([6f7fe05](https://github.com/zoedsoupe/proto_rune/commit/6f7fe052d0070f216f8f0add5cc88a03f49e10ae))
* implement base xrpc building blocks ([b861a78](https://github.com/zoedsoupe/proto_rune/commit/b861a786c7b621cb65052d223644001bd24f5fdd))
* rebrand package to proto_rune ([1fcf3cc](https://github.com/zoedsoupe/proto_rune/commit/1fcf3cc87e945b30f2ee9647a39dac6baec9547c))
* refactored wip finished ([7368d8a](https://github.com/zoedsoupe/proto_rune/commit/7368d8ab07e0a40ed8756c328b5e3c04901c67a0))
* split functions to it own namespace ([a0fb8b7](https://github.com/zoedsoupe/proto_rune/commit/a0fb8b78b8640bec3e2c1685c1aedd1bb5a64a87))
* start to move contexts and atproto identity management/resolution ([8fb4d35](https://github.com/zoedsoupe/proto_rune/commit/8fb4d35e98b52da986dabc28f556f450a401d378))


### Bug Fixes

* apply authentication for authenticated routes ([03d6aec](https://github.com/zoedsoupe/proto_rune/commit/03d6aec9390aa1847870ca31d592de5e04789aac))
* **bsky:** build proper reply refs for reply_to posts ([12e6999](https://github.com/zoedsoupe/proto_rune/commit/12e699972d30ca1c5efb23371a7be0eb14e9479d)), closes [#22](https://github.com/zoedsoupe/proto_rune/issues/22)
* correct ci ([574eeae](https://github.com/zoedsoupe/proto_rune/commit/574eeae43c56abd7ae338a2528b3335aa9fb6280))
* credo and dialyzer ([4a1bc52](https://github.com/zoedsoupe/proto_rune/commit/4a1bc52b8163fc4d7abeb1171fcf65aae135c296))


### Documentation

* massive docs, better public api definition ([590a6c9](https://github.com/zoedsoupe/proto_rune/commit/590a6c91ed7e98523207ffac61cf7266ea872644))
* solve documentation + type refs for release ([e0d7f93](https://github.com/zoedsoupe/proto_rune/commit/e0d7f93f2466d70e2253147bc5951e423a2ec7e5))


### Miscellaneous Chores

* fix compiling warnings, failing test + credo ([f3628fa](https://github.com/zoedsoupe/proto_rune/commit/f3628fa827598d28ead2ba20163470f504ff7b0b))
* fix dialyzer ([055746a](https://github.com/zoedsoupe/proto_rune/commit/055746ad2e5d19018d11dbff77c0c1172733a99b))
* fix elixir version drift in formatter ([610bc4a](https://github.com/zoedsoupe/proto_rune/commit/610bc4a9830a11883420b53b78de8bbecc446444))


### Code Refactoring

* Refactor schema generator to improve maintainability, error handling, and logging ([dd894b1](https://github.com/zoedsoupe/proto_rune/commit/dd894b1d5b4eff8412639cab328769a765c94cb0))
* revamp, lets restart simple ([1a58a0e](https://github.com/zoedsoupe/proto_rune/commit/1a58a0ef4b9ca9a1e9810d50bdaaa41c3d86d7e6))


### Continuous Integration

* add new elixir versions ([9f490fc](https://github.com/zoedsoupe/proto_rune/commit/9f490fca952aa0c369af925f87339d6ec3013d1e))
