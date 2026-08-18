defmodule ProtoRune.Session do
  @moduledoc """
  Behaviour unifying the session types that can authenticate XRPC requests.

  Two session implementations exist:

  - `ProtoRune.Atproto.Session` - app password sessions, authenticating
    with a plain `Bearer` access JWT
  - `ProtoRune.Atproto.OAuth.Session` - OAuth sessions, authenticating
    with a DPoP-bound access token and a per-request DPoP proof

  The XRPC layer dispatches through this module instead of matching on
  token fields, so any struct implementing the behaviour works:

      {:ok, headers, session} = ProtoRune.Session.authorization_headers(session, "GET", url)

  `authorization_headers/3` returns the (possibly updated) session so
  implementations can keep per-request state, such as a DPoP nonce,
  explicit and testable.
  """

  @type t :: ProtoRune.Atproto.Session.t() | ProtoRune.Atproto.OAuth.Session.t()

  @doc """
  The XRPC base URL of the service hosting the session, when known.
  """
  @callback service_url(session :: t()) :: String.t() | nil

  @doc """
  Builds the HTTP headers authenticating a request to `url`.

  `method` is the HTTP method of the request being authenticated
  (`"GET"`, `"POST"`, ...) and `url` the target URL without query string
  or fragment, both needed to bind DPoP proofs (RFC 9449).
  """
  @callback authorization_headers(session :: t(), method :: String.t(), url :: String.t()) ::
              {:ok, headers :: map(), session :: t()} | {:error, term()}

  @doc """
  Dispatches to the session's `service_url/1` implementation.
  """
  def service_url(%mod{} = session), do: mod.service_url(session)

  @doc """
  Dispatches to the session's `authorization_headers/3` implementation.
  """
  def authorization_headers(%mod{} = session, method, url) do
    mod.authorization_headers(session, method, url)
  end
end
