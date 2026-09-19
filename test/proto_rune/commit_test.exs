defmodule ProtoRune.CommitTest do
  use ExUnit.Case, async: true

  alias ProtoRune.CBOR
  alias ProtoRune.CID
  alias ProtoRune.Commit
  alias ProtoRune.Varint

  @did "did:plc:signingtest"

  # Multicodec varint prefixes for the two supported curves
  @curve_info %{
    secp256r1: <<0x80, 0x24>>,
    secp256k1: <<0xE7, 0x01>>
  }

  defp cid(seed) do
    digest = :crypto.hash(:sha256, seed)
    %CID{version: 1, codec: 0x71, multihash: Varint.encode(0x12) <> Varint.encode(32) <> digest}
  end

  defp link(cid), do: {:tag, 42, <<0>> <> CID.to_binary(cid)}

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

  defp keypair(curve) do
    {public, private} = :crypto.generate_key(:ecdh, curve)
    multibase = "z" <> base58_encode(Map.fetch!(@curve_info, curve) <> compress(public))
    {private, multibase}
  end

  defp did_doc(multibase) do
    %{
      id: @did,
      verification_method: [
        %{id: @did <> "#atproto", type: "Multikey", controller: @did, public_key_multibase: multibase}
      ]
    }
  end

  defp unsigned_commit do
    %{
      "did" => @did,
      "version" => 3,
      "data" => link(cid("mst root")),
      "rev" => "3jxs2aaa2ai",
      "prev" => nil
    }
  end

  defp sign(commit, private, curve) do
    der = :crypto.sign(:ecdsa, :sha256, Commit.unsigned_bytes(commit), [private, curve])
    {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:"ECDSA-Sig-Value", der)
    Map.put(commit, "sig", <<r::unsigned-big-256, s::unsigned-big-256>>)
  end

  for curve <- [:secp256r1, :secp256k1] do
    describe "verify/2 with #{curve}" do
      setup do
        curve = unquote(curve)
        {private, multibase} = keypair(curve)
        commit = sign(unsigned_commit(), private, curve)
        {:ok, commit: commit, doc: did_doc(multibase), curve: curve}
      end

      test "accepts a valid signature", %{commit: commit, doc: doc} do
        assert :ok = Commit.verify(commit, doc)
      end

      test "rejects a tampered commit", %{commit: commit, doc: doc} do
        tampered = %{commit | "rev" => "3jxs2aaa2aj"}
        assert {:error, :invalid_signature} = Commit.verify(tampered, doc)
      end

      test "rejects a did mismatch", %{commit: commit, doc: doc} do
        assert {:error, :did_mismatch} = Commit.verify(commit, %{doc | id: "did:plc:other"})
      end

      test "rejects a document without an #atproto key", %{commit: commit, doc: doc} do
        doc = %{doc | verification_method: [%{id: @did <> "#other", public_key_multibase: "zabc"}]}
        assert {:error, :missing_signing_key} = Commit.verify(commit, doc)
      end

      test "rejects a malformed signature", %{commit: commit, doc: doc} do
        assert {:error, :invalid_signature_encoding} = Commit.verify(%{commit | "sig" => <<1, 2, 3>>}, doc)
      end
    end
  end

  describe "unsigned_bytes/1" do
    test "encodes the commit without the sig field" do
      commit = Map.put(unsigned_commit(), "sig", :crypto.strong_rand_bytes(64))
      assert {:ok, decoded, <<>>} = CBOR.decode(Commit.unsigned_bytes(commit))
      refute Map.has_key?(decoded, "sig")
      assert decoded["did"] == @did
    end
  end
end
