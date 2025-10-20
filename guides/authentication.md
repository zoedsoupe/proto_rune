# Authentication

ProtoRune supports password-based authentication with app passwords. OAuth support is planned for future releases.

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
    File.write!("session.json", Jason.encode!(%{
      refresh_jwt: session.refresh_jwt,
      access_jwt: session.access_jwt,
      did: session.did
    }))
  end

  def load_session do
    case File.read("session.json") do
      {:ok, content} ->
        data = Jason.decode!(content)
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

## OAuth (Future)

OAuth support is planned for v0.3.0. This will enable:

- Web application authentication flows
- Token-based access without password sharing
- PKCE support for public clients
- Authorization code flow for server applications

Check the roadmap for OAuth implementation status.
