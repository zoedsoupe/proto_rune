defmodule ProtoRune do
  @moduledoc """
  Main API for ProtoRune - Elixir SDK for AT Protocol.

  ProtoRune provides a functional, type-safe interface for interacting with
  AT Protocol services, including Bluesky.

  ## Quick Start

      # Login to create a session
      {:ok, session} = ProtoRune.login("alice.bsky.social", "app-password")

      # Post to Bluesky
      {:ok, post} = ProtoRune.post(session, "Hello from Elixir!")

      # Identity resolution
      {:ok, did} = ProtoRune.resolve_handle("bob.bsky.social")

  ## Architecture

  - **Core API** (this module): Simple, high-level functions
  - **ATProto Layer**: Protocol operations (Identity, Repo, Server)
  - **Bsky Layer**: Bluesky-specific API
  - **Bot Framework**: Event-driven bot development
  """

  alias ProtoRune.Atproto.Identity
  alias ProtoRune.Atproto.Server
  alias ProtoRune.Atproto.Session

  require Identity

  @type session :: Session.t() | map()
  @type user_identifier :: String.t()
  @type user_password :: String.t()
  @type handle :: String.t()
  @type did :: String.t()
  @type error :: {:error, term()}

  @doc """
  Authenticates with AT Protocol and creates a session.

  ## Parameters

  - `identifier` - Handle (e.g., "alice.bsky.social") or email
  - `password` - App password (NOT your main account password)
  - `opts` - Optional keyword list:
    - `:service` - Service URL (default: "https://bsky.social")

  ## Returns

  - `{:ok, session}` - Session with access tokens and DID
  - `{:error, reason}` - Authentication failed

  ## Examples

      {:ok, session} = ProtoRune.login("alice.bsky.social", "abcd-1234-efgh-5678")

      {:ok, session} = ProtoRune.login(
        "alice.bsky.social",
        "abcd-1234-efgh-5678",
        service: "https://custom-pds.example.com"
      )
  """
  @spec login(user_identifier(), user_password(), keyword()) :: {:ok, session()} | error()
  def login(identifier, password, opts \\ []) when is_binary(identifier) and is_binary(password) do
    service = Keyword.get(opts, :service)

    params = %{
      identifier: identifier,
      password: password
    }

    with {:ok, data} <- Server.create_session(params) do
      data = if service, do: Map.put(data, :service_url, service), else: data
      Session.parse(data)
    end
  end

  @doc """
  Refreshes an expired session using the refresh token.

  ## Examples

      {:ok, fresh_session} = ProtoRune.refresh_session(session)
  """
  @spec refresh_session(session()) :: {:ok, session()} | error()
  def refresh_session(%{refresh_jwt: _} = session) do
    with {:ok, data} <- Server.refresh_session(session) do
      Session.parse(data)
    end
  end

  def refresh_session(_), do: {:error, :missing_refresh_jwt}

  @doc """
  Gets current session information.

  ## Examples

      {:ok, info} = ProtoRune.get_session(session)
  """
  @spec get_session(session()) :: {:ok, map()} | error()
  def get_session(%{access_jwt: _} = session) do
    Server.get_session(session)
  end

  def get_session(_), do: {:error, :missing_access_jwt}

  @doc """
  Resolves a handle to a DID (Decentralized Identifier).

  Results are cached for 1 hour.

  ## Examples

      {:ok, did} = ProtoRune.resolve_handle("alice.bsky.social")
      # => {:ok, "did:plc:abc123xyz"}
  """
  @spec resolve_handle(handle()) :: {:ok, did()} | error()
  defdelegate resolve_handle(handle), to: Identity

  @doc """
  Resolves a DID to its DID document.

  Results are cached for 24 hours.

  ## Examples

      {:ok, doc} = ProtoRune.resolve_did("did:plc:abc123xyz")
  """
  @spec resolve_did(did()) :: {:ok, map()} | error()
  defdelegate resolve_did(did), to: Identity

  @doc """
  Validates that a handle correctly maps to its DID.

  ## Examples

      {:ok, doc} = ProtoRune.validate_identity("alice.bsky.social")
  """
  @spec validate_identity(handle()) :: {:ok, map()} | error()
  defdelegate validate_identity(handle), to: Identity

  @doc """
  Posts a text message to Bluesky.

  ## Examples

      {:ok, post} = ProtoRune.post(session, "Hello Bluesky!")

      {:ok, post} = ProtoRune.post(session, "Hello!", langs: ["en"])
  """
  @spec post(session(), String.t(), keyword()) :: {:ok, map()} | error()
  def post(session, text, opts \\ []) when is_binary(text) do
    ProtoRune.Bsky.post(session, text, opts)
  end

  @doc """
  Guard to check if a value is a valid DID format.
  """
  defguard is_did(term) when Identity.is_did(term)

  @doc """
  Guard to check if a value is a valid handle format.
  """
  defguard is_handle(term) when Identity.is_handle(term)

  @doc """
  Validates DID syntax (does not resolve or verify).
  """
  @spec valid_did?(term()) :: boolean()
  defdelegate valid_did?(did), to: Identity

  @doc """
  Validates handle syntax (does not resolve or verify).
  """
  @spec valid_handle?(term()) :: boolean()
  defdelegate valid_handle?(handle), to: Identity
end
