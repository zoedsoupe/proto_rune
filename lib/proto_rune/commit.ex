defmodule ProtoRune.Commit do
  @moduledoc """
  Verification of signed repository commits.

  Every repository head is a commit block: a DAG-CBOR map with the repo's
  `did`, the MST root under `data`, a revision `rev`, the previous commit
  link `prev` (or null) and an ECDSA `sig` over the canonical DAG-CBOR
  encoding of the commit without the `sig` field.

  The signature is produced by the repo's signing key, advertised in the
  `#atproto` verification method of the repo's DID document. Both P-256
  (ES256) and secp256k1 (ES256K) keys are supported.

  This module is pure: it takes a decoded commit block and a DID document
  and never performs IO. `ProtoRune.Atproto.Sync.verify_checkout/2` wires
  it to DID resolution and CAR parsing.

  ## Examples

      {:ok, blocks} = Sync.parse_car(car)
      {:ok, commit_cid} = CAR.read(car) |> elem(1) |> Map.fetch!(:roots) |> List.first() |> ...
      :ok = Commit.verify(blocks[commit_cid], did_document)
  """

  alias ProtoRune.CBOR

  @p256 <<0x80, 0x24>>
  @k256 <<0xE7, 0x01>>

  # Curve parameters for point decompression, needed because DID documents
  # advertise compressed 33-byte public keys while :crypto.verify/5 wants
  # an uncompressed point.
  @curves %{
    secp256r1: %{
      p: 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF,
      a: 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC,
      b: 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B
    },
    secp256k1: %{
      p: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F,
      a: 0,
      b: 7
    }
  }

  @typedoc "A decoded commit block, as found under a checkout CAR's root CID."
  @type commit :: %{String.t() => term()}

  @doc """
  Verifies a decoded commit block against a DID document.

  Checks that the commit's `did` matches the document, extracts the
  `#atproto` signing key, and verifies `sig` over the canonical DAG-CBOR
  encoding of the commit without `sig`. Returns `:ok` or
  `{:error, reason}`.
  """
  @spec verify(commit(), map()) :: :ok | {:error, atom()}
  def verify(%{"did" => did, "sig" => sig} = commit, did_document)
      when is_binary(sig) and byte_size(sig) == 64 do
    with :ok <- check_did(did, did_document),
         {:ok, key, curve} <- signing_key(did_document),
         {:ok, point} <- decompress(key, curve) do
      unsigned = commit |> Map.delete("sig") |> CBOR.encode()

      if :crypto.verify(:ecdsa, :sha256, unsigned, der_signature(sig), [point, curve]) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  def verify(%{"sig" => _sig}, _did_document), do: {:error, :invalid_signature_encoding}
  def verify(_commit, _did_document), do: {:error, :invalid_commit}

  @doc """
  Returns the canonical DAG-CBOR encoding a commit's signature covers:
  the commit map without its `sig` field.
  """
  @spec unsigned_bytes(commit()) :: binary()
  def unsigned_bytes(%{} = commit), do: commit |> Map.delete("sig") |> CBOR.encode()

  defp check_did(did, %{id: did}), do: :ok
  defp check_did(_did, _doc), do: {:error, :did_mismatch}

  # The repo signing key is the verification method whose fragment is
  # `#atproto`, advertised as a multibase (base58btc, `z` prefix) key with
  # a multicodec prefix: 0x1200 for P-256, 0xe7 for secp256k1.
  defp signing_key(%{verification_method: methods}) when is_list(methods) do
    with %{} = method <- Enum.find(methods, &atproto_method?/1) || :missing,
         {:ok, bytes} <- decode_multibase(method[:public_key_multibase]) do
      case bytes do
        <<@p256, key::binary>> -> {:ok, key, :secp256r1}
        <<@k256, key::binary>> -> {:ok, key, :secp256k1}
        _other -> {:error, :unsupported_key_type}
      end
    else
      :missing -> {:error, :missing_signing_key}
      {:error, reason} -> {:error, reason}
    end
  end

  defp signing_key(_doc), do: {:error, :missing_signing_key}

  defp atproto_method?(%{id: id}) when is_binary(id), do: String.ends_with?(id, "#atproto")
  defp atproto_method?(_), do: false

  defp decode_multibase("z" <> encoded) do
    {:ok, base58_decode(encoded)}
  end

  defp decode_multibase(_other), do: {:error, :unsupported_multibase}

  # y² = x³ + ax + b (mod p); both supported curves have p ≡ 3 (mod 4), so
  # y = rhs^((p+1)/4) mod p and the prefix byte selects the root's parity.
  defp decompress(<<0x04, _rest::binary>> = point, _curve), do: {:ok, point}

  defp decompress(<<prefix, x::unsigned-big-256>>, curve) when prefix in [0x02, 0x03] do
    %{p: p, a: a, b: b} = Map.fetch!(@curves, curve)
    rhs = Integer.mod(x * x * x + a * x + b, p)
    y = :crypto.mod_pow(rhs, div(p + 1, 4), p) |> :binary.decode_unsigned()

    if rem(y, 2) == prefix - 0x02 do
      {:ok, <<0x04, x::unsigned-big-256, y::unsigned-big-256>>}
    else
      {:ok, <<0x04, x::unsigned-big-256, p - y::unsigned-big-256>>}
    end
  end

  defp decompress(_key, _curve), do: {:error, :invalid_public_key}

  # ATProto signatures are raw 64-byte r || s; :crypto.verify/5 expects DER.
  defp der_signature(<<r::binary-32, s::binary-32>>) do
    r_der = der_integer(r)
    s_der = der_integer(s)
    sequence = r_der <> s_der
    <<0x30, byte_size(sequence)>> <> sequence
  end

  defp der_integer(bytes) do
    int = bytes |> :binary.decode_unsigned() |> :binary.encode_unsigned()

    case int do
      <<high, _rest::binary>> when high >= 0x80 -> <<0x02, byte_size(int) + 1, 0x00>> <> int
      _other -> <<0x02, byte_size(int)>> <> int
    end
  end

  @base58_alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  defp base58_decode(string) do
    string
    |> String.to_charlist()
    |> Enum.reduce(0, fn char, acc ->
      acc * 58 + Enum.find_index(@base58_alphabet, &(&1 == char))
    end)
    |> :binary.encode_unsigned()
    |> restore_leading_zeros(string)
  end

  # Each leading '1' in base58 encodes a leading 0x00 byte that
  # encode_unsigned/1 drops.
  defp restore_leading_zeros(bytes, string) do
    zeros = String.length(string) - String.length(String.trim_leading(string, "1"))
    :binary.copy(<<0>>, zeros) <> bytes
  end
end
