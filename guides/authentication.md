# Authentication

ProtoRune supports password-based authentication with app passwords and OAuth 2.0 for applications.

## App Passwords

App passwords are the recommended way to authenticate bots and applications with Bluesky. Never use your main account password.

### Creating an App Password

1. Log in to Bluesky
2. Go to Settings → Privacy and Security → App Passwords
3. Create a new app password
4. Save the generated password (it will only be shown once)

## Basic Authentication

The `login/3` function creates a session with your credentials:

```elixir
{:ok, session} = ProtoRune.login(
  "your-handle.bsky.social",
  "your-app-password"
)
```

### Login Parameters

- `identifier`: Your handle (e.g., "alice.bsky.social") or email
- `password`: Your app password (not your main account password)
- `opts`: Optional keyword list
  - `:service`: Service URL (default: "https://bsky.social")

### Custom Service URL

To connect to a different PDS (Personal Data Server):

```elixir
{:ok, session} = ProtoRune.login(
  "alice.bsky.social",
  "app-password",
  service: "https://custom-pds.example.com"
)
```

## Session Management

### Session Structure

A session contains:

```elixir
%{
  access_jwt: "eyJ...",        # Short-lived access token
  refresh_jwt: "eyJ...",       # Long-lived refresh token
  did: "did:plc:abc123",       # Your DID
  handle: "alice.bsky.social", # Your handle
  service_url: "https://...",  # Your PDS endpoint
  did_doc: %{...}              # Your DID document
}
```

### Token Refresh

Access tokens expire after a period of time. Use `refresh_session/1` to get a fresh access token:

```elixir
case ProtoRune.refresh_session(session) do
  {:ok, fresh_session} ->
    # Use fresh_session for subsequent requests
    ProtoRune.Bsky.post(fresh_session, "Posted with refreshed session")

  {:error, :missing_refresh_jwt} ->
    # Session doesn't have a refresh token
    # Need to login again

  {:error, reason} ->
    # Refresh failed, may need to re-authenticate
    IO.puts("Refresh failed: #{inspect(reason)}")
end
```

### Session Information

Get current session details:

```elixir
{:ok, info} = ProtoRune.get_session(session)
```

This returns information about your current session without refreshing tokens.

## Storing Sessions

For persistent applications, you may want to store session tokens:

```elixir
defmodule MyApp.SessionStore do
  def save_session(session) do
    # Store refresh_jwt securely
    # Never store in version control
    # Consider encryption for sensitive storage
    File.write!("session.json", JSON.encode!(%{
      refresh_jwt: session.refresh_jwt,
      access_jwt: session.access_jwt,
      did: session.did
    }))
  end

  def load_session do
    case File.read("session.json") do
      {:ok, content} ->
        data = JSON.decode!(content)
        {:ok, Map.new(data, fn {k, v} -> {String.to_atom(k), v} end)}

      {:error, _} ->
        {:error, :no_saved_session}
    end
  end
end
```

Then restore on application start:

```elixir
case MyApp.SessionStore.load_session() do
  {:ok, stored_session} ->
    # Verify session is still valid
    case ProtoRune.get_session(stored_session) do
      {:ok, _info} ->
        stored_session

      {:error, _} ->
        # Session expired, refresh or re-login
        ProtoRune.refresh_session(stored_session)
    end

  {:error, :no_saved_session} ->
    # Need to login
    ProtoRune.login(identifier, password)
end
```

## Security Best Practices

### Credential Management

1. **Never hardcode credentials** in source code
2. **Use environment variables** for development
3. **Use secure secret management** in production

```elixir
# Good: Environment variables
identifier = System.get_env("BSKY_IDENTIFIER")
password = System.get_env("BSKY_APP_PASSWORD")

# Bad: Hardcoded (never do this)
identifier = "alice.bsky.social"
password = "abcd-1234-efgh-5678"
```

### Token Storage

1. **Encrypt tokens** when storing to disk
2. **Set restrictive file permissions** (0600)
3. **Never commit tokens** to version control
4. **Add session files to .gitignore**

```elixir
# .gitignore
session.json
*.session
```

### Token Rotation

Implement automatic token refresh in long-running applications:

```elixir
defmodule MyApp.SessionManager do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Initial login
    {:ok, session} = ProtoRune.login(
      opts[:identifier],
      opts[:password]
    )

    # Schedule refresh every 4 hours
    schedule_refresh()

    {:ok, %{session: session}}
  end

  def handle_info(:refresh, state) do
    case ProtoRune.refresh_session(state.session) do
      {:ok, fresh_session} ->
        schedule_refresh()
        {:noreply, %{state | session: fresh_session}}

      {:error, _reason} ->
        # Refresh failed, could re-login or stop
        {:stop, :refresh_failed, state}
    end
  end

  defp schedule_refresh do
    # Refresh every 4 hours (14400 seconds)
    Process.send_after(self(), :refresh, 14_400_000)
  end
end
```

## Error Handling

Common authentication errors:

```elixir
case ProtoRune.login(identifier, password) do
  {:ok, session} ->
    session

  {:error, %{error: "AuthenticationRequired"}} ->
    # Invalid credentials
    IO.puts("Invalid username or password")

  {:error, %{error: "InvalidToken"}} ->
    # Token expired or invalid
    IO.puts("Token is invalid, please re-authenticate")

  {:error, reason} ->
    # Network or other errors
    IO.puts("Login error: #{inspect(reason)}")
end
```

## Testing with Authentication

For testing, consider using test accounts or mocking:

```elixir
defmodule MyApp.Test do
  use ExUnit.Case

  setup do
    # Option 1: Use test account
    {:ok, session} = ProtoRune.login(
      System.get_env("TEST_IDENTIFIER"),
      System.get_env("TEST_PASSWORD")
    )

    # Option 2: Mock session (for unit tests)
    mock_session = %{
      access_jwt: "test-access-token",
      refresh_jwt: "test-refresh-token",
      did: "did:plc:test123",
      handle: "test.bsky.social"
    }

    {:ok, session: session}
  end

  test "can post with authenticated session", %{session: session} do
    {:ok, post} = ProtoRune.Bsky.post(session, "Test post")
    assert post.uri
  end
end
```

## OAuth

OAuth is the recommended flow for applications acting on behalf of users, since tokens are granted without sharing a password. ProtoRune implements the AT Protocol OAuth profile for public clients: authorization code flow with PAR, PKCE and DPoP, using only `:crypto` (no JWT dependency).

### Requirements

Your application must serve a client metadata document at its `client_id` URL declaring the redirect URIs and scope. See the [AT Protocol OAuth spec](https://atproto.com/specs/oauth) for the document format.

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
# Redirect the user to `url` and persist `pending` (e.g. in the web session)

# 3. On the callback, exchange the code for tokens
{:ok, session} = OAuth.exchange_code(client, pending, conn.query_params)
```

The `pending` map and the returned session contain the DPoP private key: persist them securely and never expose them to the browser.

To keep the DPoP key across restarts, store `client.dpop_key` (a 32-byte binary) and pass it back with `dpop_key:` when rebuilding the client.

### Using the Session

An OAuth session works anywhere an app password session does. Every XRPC and DSL function dispatches through the `ProtoRune.Session` behaviour, which attaches the DPoP proof each request needs:

```elixir
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "alice.bsky.social")
{:ok, post} = ProtoRune.Bsky.post(session, "Hello from OAuth!")
```

### Refreshing Tokens

Access tokens are short-lived. When you manage the session yourself, refresh it manually:

```elixir
{:ok, fresh_session} = OAuth.refresh(client, session)
```

Refresh tokens rotate: the fresh session may carry a new refresh token, so always keep the newest session and discard the old one.

### Revoking a Session

On logout, revoke the refresh token so it can no longer be used:

```elixir
{:ok, :revoked} = OAuth.revoke(session, client_id: client.client_id)
```

Revocation looks up the authorization server's `revocation_endpoint` in its metadata and returns `{:error, :revocation_not_supported}` when the server declares none. Per RFC 7009 the server answers success even for unknown tokens, so `{:ok, :revoked}` means the token is gone, not that it was still valid.

### Managing the Session Lifecycle

For long-running applications, `ProtoRune.Atproto.OAuth.SessionManager` keeps a session fresh for you. It refreshes the tokens before they expire, persists each rotated session through a `ProtoRune.Security.TokenStore` backend and stops if a refresh fails, letting your supervisor decide what to do.

The SDK starts no processes on its own: add the manager to your application's supervision tree, alongside a `Registry` if you want to look managers up by DID:

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

The `:key` option encrypts the session before it reaches the store; see `ProtoRune.Security` for how to provision it. With `:registry` set, the manager registers itself under the session's DID, so any process can fetch the current session without holding the pid:

```elixir
via = {:via, Registry, {MyApp.OAuthRegistry, "did:plc:abc123"}}
session = ProtoRune.Atproto.OAuth.SessionManager.session(via)
{:ok, profile} = ProtoRune.Bsky.get_profile(session, "alice.bsky.social")
```

On logout, `logout/1` revokes the refresh token, deletes the stored session and stops the manager:

```elixir
:ok = ProtoRune.Atproto.OAuth.SessionManager.logout(via)
```

### Current limitations

- Only public clients are supported (no `private_key_jwt` confidential clients).
