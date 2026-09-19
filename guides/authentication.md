# Authentication

Two ways in: app passwords (bots, scripts) and OAuth (apps acting on behalf of users).

## App passwords

Create one at Settings → Privacy and Security → App Passwords on Bluesky. It is shown once, save it. Never use your main account password.

```elixir
{:ok, session} = ProtoRune.login("you.bsky.social", "your-app-password")
```

Options:

- `identifier`: handle or email
- `password`: the app password
- `:service`: PDS URL (default `"https://bsky.social"`)

Custom PDS:

```elixir
{:ok, session} = ProtoRune.login("alice.bsky.social", "app-password",
  service: "https://custom-pds.example.com"
)
```

## Session management

A session is a struct: `%ProtoRune.Atproto.Session{}` for app passwords, `%ProtoRune.Atproto.OAuth.Session{}` for OAuth. Treat it as opaque and read account info through the `ProtoRune.Session` accessors, whose names are stable across both types:

```elixir
ProtoRune.Session.did(session)         # "did:plc:abc123"
ProtoRune.Session.handle(session)      # "alice.bsky.social"
ProtoRune.Session.service_url(session) # "https://bsky.social/xrpc"
```

Refresh when the access token expires:

```elixir
{:ok, fresh_session} = ProtoRune.refresh_session(session)
```

Inspect without refreshing:

```elixir
{:ok, info} = ProtoRune.get_session(session)
```

## Storing sessions

Persist the tokens, reload and validate on boot. Rebuild the struct, a plain map won't dispatch:

```elixir
def load_or_login(identifier, password) do
  with {:ok, content} <- File.read("session.json"),
       {:ok, data} <- JSON.decode(content),
       {:ok, session} <- parse_session(data),
       {:ok, _info} <- ProtoRune.get_session(session) do
    {:ok, session}
  else
    _ -> ProtoRune.login(identifier, password)
  end
end

# JSON.decode/1 returns string keys; the session parser expects atoms
defp parse_session(data) do
  data
  |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
  |> ProtoRune.Atproto.Session.parse()
rescue
  ArgumentError -> {:error, :invalid_session}
end
```

## Security

- Credentials come from env vars, never source code:

```elixir
identifier = System.fetch_env!("BSKY_IDENTIFIER")
password = System.fetch_env!("BSKY_APP_PASSWORD")
```

- Encrypt tokens at rest, use `0600` permissions.
- Add session files to `.gitignore`.

## OAuth

For apps acting on behalf of users. ProtoRune implements the AT Protocol OAuth profile for public clients: authorization code flow with PAR, PKCE and DPoP, using only `:crypto` (no JWT dependency).

Your app must serve a client metadata document at its `client_id` URL. See the [AT Protocol OAuth spec](https://atproto.com/specs/oauth) for the format.

### Flow

```elixir
alias ProtoRune.Atproto.OAuth
alias ProtoRune.Atproto.OAuth.Client

# 1. Configure the client (a DPoP key pair is generated for you)
{:ok, client} =
  Client.new(
    client_id: "https://myapp.example.com/oauth/client-metadata.json",
    redirect_uri: "https://myapp.example.com/oauth/callback"
  )

# 2. Send the user to their authorization server
{:ok, url, pending} = OAuth.authorization_url(client, "alice.bsky.social")
# Redirect to `url`, persist `pending` (e.g. in the web session)

# 3. On the callback, exchange the code
{:ok, session} = OAuth.exchange_code(client, pending, conn.query_params)
```

The `pending` map and the session contain the DPoP private key: persist them securely, never expose them to the browser. To keep the key across restarts, store `client.dpop_key` (32-byte binary) and pass it back with `dpop_key:` when rebuilding the client.

An OAuth session works anywhere an app password session does:

```elixir
{:ok, post} = ProtoRune.Bsky.post(session, "Hello from OAuth!")
```

Refresh tokens rotate, so always keep the newest session:

```elixir
{:ok, fresh_session} = ProtoRune.refresh_session(session, client: client)
```

Revoke on logout:

```elixir
{:ok, :revoked} = OAuth.revoke(session, client_id: client.client_id)
```

Per RFC 7009 the server answers success even for unknown tokens, so `{:ok, :revoked}` means the token is gone, not that it was still valid. Returns `{:error, :revocation_not_supported}` when the server declares no revocation endpoint.

### SessionManager

For long-running apps, `ProtoRune.Atproto.OAuth.SessionManager` keeps a session fresh: it refreshes before expiry, persists each rotated session through a `ProtoRune.Security.TokenStore` backend (encrypted at rest, the DPoP key is private key material) and stops on refresh failure so your supervisor decides what to do.

The SDK starts no processes on its own, add it to your supervision tree:

```elixir
# once, to provision the encryption key:
key = ProtoRune.Security.generate_key()
System.put_env("PROTO_RUNE_TOKEN_KEY", ProtoRune.Security.encode_key(key))
```

```elixir
# application.ex
{:ok, key} = ProtoRune.Security.decode_key(System.fetch_env!("PROTO_RUNE_TOKEN_KEY"))

children = [
  {Registry, keys: :unique, name: MyApp.OAuthRegistry},
  {ProtoRune.Atproto.OAuth.SessionManager,
   session: session,
   client: client,
   store: {ProtoRune.Security.TokenStore.Dets, path: "/var/myapp/tokens.dets"},
   key: key,
   registry: MyApp.OAuthRegistry}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

With `:registry` set, any process can fetch the current session by DID:

```elixir
via = {:via, Registry, {MyApp.OAuthRegistry, "did:plc:abc123"}}
session = ProtoRune.Atproto.OAuth.SessionManager.session(via)
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "alice.bsky.social")
```

`logout/1` revokes the refresh token, deletes the stored session and stops the manager:

```elixir
:ok = ProtoRune.Atproto.OAuth.SessionManager.logout(via)
```

### Limitations

- Only public clients are supported (no `private_key_jwt` confidential clients).
