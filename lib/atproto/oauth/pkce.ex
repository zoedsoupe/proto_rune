defmodule ProtoRune.Atproto.OAuth.PKCE do
  @moduledoc """
  Proof Key for Code Exchange (PKCE) helpers for the AT Protocol OAuth flow.

  Implements the S256 code challenge method from RFC 7636 using only
  `:crypto`. The code verifier is a high-entropy random string sent to the
  token endpoint, while the code challenge is its SHA-256 hash sent during
  the authorization request.
  """

  @verifier_bytes 32

  @doc """
  Generates a random code verifier.

  Returns a base64url-encoded string (without padding) derived from 32
  cryptographically secure random bytes.
  """
  @spec generate_verifier() :: String.t()
  def generate_verifier do
    @verifier_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Computes the S256 code challenge for a code verifier.

  ## Examples

      iex> PKCE.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
      "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
  """
  @spec challenge(String.t()) :: String.t()
  def challenge(verifier) when is_binary(verifier) do
    :sha256
    |> :crypto.hash(verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Generates a `{code_verifier, code_challenge}` pair.
  """
  @spec generate() :: {String.t(), String.t()}
  def generate do
    verifier = generate_verifier()
    {verifier, challenge(verifier)}
  end
end
