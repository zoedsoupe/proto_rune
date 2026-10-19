defmodule ProtoRune.Atproto.Identity.SigningKeyTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Atproto.Identity.SigningKey

  @did "did:plc:signingkeytest"

  # Test vectors from the atproto DID spec: the same secp256k1 key in
  # both encodings.
  @spec_legacy "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
  @spec_multikey "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"

  @multicodec %{secp256r1: <<0x80, 0x24>>, secp256k1: <<0xE7, 0x01>>}

  @legacy_type %{
    secp256r1: "EcdsaSecp256r1VerificationKey2019",
    secp256k1: "EcdsaSecp256k1VerificationKey2019"
  }

  describe "from_did_doc/1" do
    test "decodes the spec's legacy and multikey vectors to the same key" do
      assert {:ok, legacy_point, :secp256k1} =
               from_doc(Map.fetch!(@legacy_type, :secp256k1), @spec_legacy)

      assert {:ok, multikey_point, :secp256k1} = from_doc("Multikey", @spec_multikey)

      assert legacy_point == multikey_point
      assert <<0x04, _x::binary-32, _y::binary-32>> = legacy_point
    end

    test "decodes a generated P-256 key in both encodings to the same point" do
      {public, _private} = :crypto.generate_key(:ecdh, :secp256r1)
      legacy = "z" <> base58_encode(public)
      multikey = "z" <> base58_encode(Map.fetch!(@multicodec, :secp256r1) <> compress(public))

      assert {:ok, legacy_point, :secp256r1} =
               from_doc(Map.fetch!(@legacy_type, :secp256r1), legacy)

      assert {:ok, multikey_point, :secp256r1} = from_doc("Multikey", multikey)

      assert legacy_point == multikey_point
      assert legacy_point == public
    end

    test "errors when no #atproto method exists" do
      doc = did_doc([method(@did <> "#other", "Multikey", @spec_multikey)])
      assert {:error, :missing_signing_key} = SigningKey.from_did_doc(doc)
    end

    test "errors on an unknown method type" do
      doc = did_doc([method(@did <> "#atproto", "Ed25519VerificationKey2020", @spec_multikey)])
      assert {:error, :unsupported_key_type} = SigningKey.from_did_doc(doc)
    end
  end

  defp from_doc(type, multibase) do
    SigningKey.from_did_doc(did_doc([method(@did <> "#atproto", type, multibase)]))
  end

  defp did_doc(methods), do: %{id: @did, verification_method: methods}

  defp method(id, type, multibase) do
    %{id: id, type: type, controller: @did, public_key_multibase: multibase}
  end

  defp base58_encode(binary) do
    zeros = byte_size(binary) - byte_size(String.trim_leading(binary, <<0>>))

    binary
    |> :binary.decode_unsigned()
    |> then(fn int -> if int == 0, do: "", else: digits(int, "") end)
    |> then(&(String.duplicate("1", zeros) <> &1))
  end

  @alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  defp digits(0, acc), do: acc

  defp digits(int, acc) do
    digits(div(int, 58), <<Enum.at(@alphabet, rem(int, 58))>> <> acc)
  end

  defp compress(<<4, x::binary-32, y::binary-32>>) do
    prefix = if rem(:binary.last(y), 2) == 0, do: 0x02, else: 0x03
    <<prefix>> <> x
  end
end
