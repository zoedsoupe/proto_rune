defmodule ProtoRune.Atproto.OAuth.DPoP do
  @moduledoc """
  DPoP (Demonstrating Proof of Possession, RFC 9449) support for the
  AT Protocol OAuth flow.

  AT Protocol requires clients to bind tokens to an ES256 (ECDSA over
  P-256) key pair and to attach a signed DPoP proof JWT to authorization
  server requests. This module implements key generation, JWK encoding and
  proof signing with `:crypto` and `:public_key` only, with no external
  JWT dependency.

  Private keys are raw 32-byte binaries and can be persisted by the caller
  to resume a session later.
  """

  @curve :secp256r1

  @type private_key :: <<_::256>>
  @type jwk :: %{String.t() => String.t()}

  @doc """
  Generates a fresh ES256 key pair.

  Returns `{private_key, public_jwk}` where `private_key` is a raw 32-byte
  binary and `public_jwk` is the public key in JWK form, ready to embed in
  DPoP proof headers.
  """
  @spec generate_key() :: {private_key(), jwk()}
  def generate_key do
    {public, private} = :crypto.generate_key(:ecdh, @curve)
    {private, encode_jwk(public)}
  end

  @doc """
  Derives the public JWK for an existing private key.

  Useful when the caller persisted the private key and needs to rebuild
  the JWK without storing it.
  """
  @spec public_jwk(private_key()) :: jwk()
  def public_jwk(private) when is_binary(private) and byte_size(private) == 32 do
    {public, ^private} = :crypto.generate_key(:ecdh, @curve, private)
    encode_jwk(public)
  end

  @doc """
  Builds a signed DPoP proof JWT for a request.

  ## Parameters

  - `private` - The ES256 private key (32-byte binary)
  - `jwk` - The matching public JWK, embedded in the proof header
  - `method` - The HTTP method of the request being proven (`:get`, `:post`, ...)
  - `url` - The target URL (query string and fragment are stripped per RFC 9449)
  - `opts` - Optional keyword list:
    - `:nonce` - Server-provided DPoP nonce
    - `:access_token` - Access token to bind via the `ath` claim
  """
  @spec proof(private_key(), jwk(), atom() | String.t(), String.t(), keyword()) :: String.t()
  def proof(private, jwk, method, url, opts \\ []) do
    header = %{"alg" => "ES256", "typ" => "dpop+jwt", "jwk" => jwk}

    claims =
      %{
        "jti" => b64url(:crypto.strong_rand_bytes(16)),
        "htm" => method |> to_string() |> String.upcase(),
        "htu" => normalize_htu(url),
        "iat" => System.system_time(:second)
      }
      |> maybe_put("nonce", Keyword.get(opts, :nonce))
      |> maybe_put_ath(Keyword.get(opts, :access_token))

    signing_input = b64url(JSON.encode!(header)) <> "." <> b64url(JSON.encode!(claims))
    signing_input <> "." <> b64url(sign(private, signing_input))
  end

  # The htu claim must not contain query or fragment components (RFC 9449, 4.2)
  defp normalize_htu(url) do
    url
    |> URI.parse()
    |> Map.merge(%{query: nil, fragment: nil})
    |> URI.to_string()
  end

  defp maybe_put(claims, _key, nil), do: claims
  defp maybe_put(claims, key, value), do: Map.put(claims, key, value)

  defp maybe_put_ath(claims, nil), do: claims

  defp maybe_put_ath(claims, access_token) do
    Map.put(claims, "ath", b64url(:crypto.hash(:sha256, access_token)))
  end

  defp encode_jwk(<<4, x::binary-32, y::binary-32>>) do
    %{"kty" => "EC", "crv" => "P-256", "x" => b64url(x), "y" => b64url(y)}
  end

  defp sign(private, payload) do
    der = :crypto.sign(:ecdsa, :sha256, payload, [private, @curve])
    {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:"ECDSA-Sig-Value", der)
    <<r::unsigned-big-256, s::unsigned-big-256>>
  end

  defp b64url(binary), do: Base.url_encode64(binary, padding: false)
end
