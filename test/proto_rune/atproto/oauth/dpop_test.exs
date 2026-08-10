defmodule ProtoRune.Atproto.OAuth.DPoPTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Atproto.OAuth.DPoP

  describe "generate_key/0" do
    test "returns a 32-byte private key and a P-256 JWK" do
      {private, jwk} = DPoP.generate_key()

      assert byte_size(private) == 32
      assert jwk["kty"] == "EC"
      assert jwk["crv"] == "P-256"
      assert is_binary(jwk["x"])
      assert is_binary(jwk["y"])
    end

    test "JWK coordinates match the public key point" do
      {private, jwk} = DPoP.generate_key()
      {<<4, x::binary-32, y::binary-32>>, ^private} = :crypto.generate_key(:ecdh, :secp256r1, private)

      assert Base.url_decode64!(jwk["x"], padding: false) == x
      assert Base.url_decode64!(jwk["y"], padding: false) == y
    end
  end

  describe "public_jwk/1" do
    test "derives the same JWK produced at key generation" do
      {private, jwk} = DPoP.generate_key()

      assert DPoP.public_jwk(private) == jwk
    end
  end

  describe "proof/5" do
    setup do
      {private, jwk} = DPoP.generate_key()
      {:ok, private: private, jwk: jwk}
    end

    test "builds a verifiable ES256 DPoP proof", %{private: private, jwk: jwk} do
      proof = DPoP.proof(private, jwk, :post, "https://auth.example.com/oauth/token")

      [encoded_header, encoded_claims, encoded_sig] = String.split(proof, ".")
      header = decode(encoded_header)
      claims = decode(encoded_claims)

      assert header["alg"] == "ES256"
      assert header["typ"] == "dpop+jwt"
      assert header["jwk"] == jwk

      assert claims["htm"] == "POST"
      assert claims["htu"] == "https://auth.example.com/oauth/token"
      assert is_binary(claims["jti"])
      assert is_integer(claims["iat"])
      refute Map.has_key?(claims, "nonce")
      refute Map.has_key?(claims, "ath")

      assert verify_signature(encoded_header, encoded_claims, encoded_sig, private)
    end

    test "strips query and fragment from htu", %{private: private, jwk: jwk} do
      proof = DPoP.proof(private, jwk, :get, "https://pds.example.com/xrpc/app.bsky.feed.getTimeline?limit=10#frag")
      [_header, encoded_claims, _sig] = String.split(proof, ".")

      assert decode(encoded_claims)["htu"] == "https://pds.example.com/xrpc/app.bsky.feed.getTimeline"
    end

    test "includes the nonce when given", %{private: private, jwk: jwk} do
      proof = DPoP.proof(private, jwk, :post, "https://auth.example.com/oauth/par", nonce: "nonce-1")
      [_header, encoded_claims, _sig] = String.split(proof, ".")

      assert decode(encoded_claims)["nonce"] == "nonce-1"
    end

    test "binds the access token hash when given", %{private: private, jwk: jwk} do
      token = "access-token-123"
      proof = DPoP.proof(private, jwk, :get, "https://pds.example.com/xrpc/endpoint", access_token: token)
      [_header, encoded_claims, _sig] = String.split(proof, ".")

      expected_ath = :sha256 |> :crypto.hash(token) |> Base.url_encode64(padding: false)
      assert decode(encoded_claims)["ath"] == expected_ath
    end
  end

  defp decode(segment) do
    segment
    |> Base.url_decode64!(padding: false)
    |> JSON.decode!()
  end

  defp verify_signature(encoded_header, encoded_claims, encoded_sig, private) do
    <<r::unsigned-big-256, s::unsigned-big-256>> = Base.url_decode64!(encoded_sig, padding: false)
    der = :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})
    {public, ^private} = :crypto.generate_key(:ecdh, :secp256r1, private)
    signing_input = encoded_header <> "." <> encoded_claims

    :crypto.verify(:ecdsa, :sha256, signing_input, der, [public, :secp256r1])
  end
end
