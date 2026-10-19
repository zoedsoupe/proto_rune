defmodule ProtoRune.Atproto.Identity.SigningKey do
  @moduledoc false

  # Extraction and use of the repo signing key advertised in a DID
  # document's `#atproto` verification method. Keys are multibase
  # (base58btc, `z` prefix) with a multicodec prefix: 0x8024 for P-256,
  # 0xe701 for secp256k1. Shared by ProtoRune.Commit (repo commits) and
  # ProtoRune.Atproto.Identity (verify_signature/3).

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

  @doc """
  Returns the `{point, curve}` of the DID document's `#atproto` signing
  key, with the point decompressed for `:crypto.verify/5`.
  """
  @spec from_did_doc(map()) :: {:ok, binary(), :secp256r1 | :secp256k1} | {:error, atom()}
  def from_did_doc(doc) when is_map(doc) do
    case get_key(doc, :verification_method) do
      methods when is_list(methods) -> extract_method(methods)
      _other -> {:error, :missing_signing_key}
    end
  end

  defp extract_method(methods) do
    with %{} = method <- Enum.find(methods, &atproto_method?/1) || :missing,
         multibase when is_binary(multibase) <- get_key(method, :public_key_multibase) || :missing,
         {:ok, bytes} <- decode_multibase(multibase),
         {:ok, key, curve} <- split_codec(bytes) do
      decompress(key, curve)
    else
      :missing -> {:error, :missing_signing_key}
      {:error, reason} -> {:error, reason}
    end
  end

  # Snakelized server documents may carry atom or string keys depending on
  # whether the atom already existed at conversion time (ProtoRune.Case
  # interns with String.to_existing_atom/1), so accept both.
  defp get_key(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  @doc """
  Verifies a raw 64-byte `r || s` ECDSA signature over `message`.
  """
  @spec verify(binary(), :secp256r1 | :secp256k1, binary(), binary()) :: boolean()
  def verify(point, curve, message, <<_::binary-64>> = sig) do
    :crypto.verify(:ecdsa, :sha256, message, der_signature(sig), [point, curve])
  end

  def verify(_point, _curve, _message, _sig), do: false

  defp atproto_method?(%{id: id}) when is_binary(id), do: String.ends_with?(id, "#atproto")
  defp atproto_method?(%{"id" => id}) when is_binary(id), do: String.ends_with?(id, "#atproto")
  defp atproto_method?(_), do: false

  defp decode_multibase("z" <> encoded) do
    {:ok, base58_decode(encoded)}
  end

  defp decode_multibase(_other), do: {:error, :unsupported_multibase}

  defp split_codec(<<@p256, key::binary>>), do: {:ok, key, :secp256r1}
  defp split_codec(<<@k256, key::binary>>), do: {:ok, key, :secp256k1}
  defp split_codec(_other), do: {:error, :unsupported_key_type}

  # y² = x³ + ax + b (mod p); both supported curves have p ≡ 3 (mod 4), so
  # y = rhs^((p+1)/4) mod p and the prefix byte selects the root's parity.
  defp decompress(<<0x04, _rest::binary>> = point, _curve), do: {:ok, point}

  defp decompress(<<prefix, x::unsigned-big-256>>, curve) when prefix in [0x02, 0x03] do
    %{p: p, a: a, b: b} = Map.fetch!(@curves, curve)
    rhs = Integer.mod(x * x * x + a * x + b, p)
    y = rhs |> :crypto.mod_pow(div(p + 1, 4), p) |> :binary.decode_unsigned()

    if rem(y, 2) == prefix - 0x02 do
      {:ok, <<0x04, x::unsigned-big-256, y::unsigned-big-256>>, curve}
    else
      {:ok, <<0x04, x::unsigned-big-256, p - y::unsigned-big-256>>, curve}
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
