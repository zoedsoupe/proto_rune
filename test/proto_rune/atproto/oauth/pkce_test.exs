defmodule ProtoRune.Atproto.OAuth.PKCETest do
  use ExUnit.Case, async: true

  alias ProtoRune.Atproto.OAuth.PKCE

  describe "generate_verifier/0" do
    test "returns a base64url string without padding" do
      verifier = PKCE.generate_verifier()

      assert is_binary(verifier)
      assert String.match?(verifier, ~r/^[A-Za-z0-9\-_]+$/)
      refute String.contains?(verifier, "=")
    end

    test "generates unique verifiers" do
      assert PKCE.generate_verifier() != PKCE.generate_verifier()
    end
  end

  describe "challenge/1" do
    test "matches the RFC 7636 appendix B test vector" do
      verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

      assert PKCE.challenge(verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    end

    test "computes the base64url-encoded SHA-256 of the verifier" do
      verifier = PKCE.generate_verifier()
      expected = :sha256 |> :crypto.hash(verifier) |> Base.url_encode64(padding: false)

      assert PKCE.challenge(verifier) == expected
    end
  end

  describe "generate/0" do
    test "returns a matching verifier and challenge pair" do
      {verifier, challenge} = PKCE.generate()

      assert PKCE.challenge(verifier) == challenge
    end
  end
end
