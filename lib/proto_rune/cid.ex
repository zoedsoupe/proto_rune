defmodule ProtoRune.CID do
  @moduledoc """
  CID (Content Identifier) values as they appear in the ATProto event stream.

  Only CIDv1 is supported, which covers every CID produced by modern ATProto
  relays and PDSes. The string representation uses the standard base32
  multibase encoding (`b` prefix), so CIDs can be compared directly against
  the CID strings returned by XRPC endpoints:

      to_string(op.cid) == record["cid"]
  """

  alias ProtoRune.Varint

  @typedoc """
  A parsed CIDv1.

    * `:version` - always `1`.
    * `:codec` - the multicodec code of the referenced data (`0x71` for
      DAG-CBOR, `0x55` for raw bytes).
    * `:multihash` - the raw multihash bytes (function code varint, digest
      size varint and digest).
  """
  @type t :: %__MODULE__{version: 1, codec: non_neg_integer, multihash: binary}

  defstruct [:version, :codec, :multihash]

  @doc """
  Parses a binary CID from the head of the given binary.

  Returns the parsed CID along with the unconsumed rest of the input, which
  allows reading the CID-prefixed block entries of a CAR file.
  """
  @spec from_binary(binary) :: {:ok, t, binary} | {:error, atom | tuple}
  def from_binary(<<1, rest::binary>>) do
    with {:ok, codec, rest} <- Varint.read(rest),
         {:ok, multihash, rest} <- read_multihash(rest) do
      {:ok, %__MODULE__{version: 1, codec: codec, multihash: multihash}, rest}
    end
  end

  def from_binary(<<version, _rest::binary>>), do: {:error, {:unsupported_cid_version, version}}
  def from_binary(<<>>), do: {:error, :unexpected_end}

  @doc """
  Decodes a CID reference into a CID.

  Accepts either a raw DAG-CBOR CID link (`{:tag, 42, bytes}`) or an
  already-parsed CID, which makes the function safe to apply to blocks
  decoded by either `ProtoRune.Atproto.Sync.parse_car/1` (raw links) or
  `ProtoRune.Firehose.Frame` (resolved links).

  DAG-CBOR prefixes the binary CID with a single `0x00` byte for historical
  multibase reasons.
  """
  @spec from_link(term) :: {:ok, t} | {:error, atom | tuple}
  def from_link(%__MODULE__{} = cid), do: {:ok, cid}

  def from_link({:tag, 42, <<0, bytes::binary>>}) do
    with {:ok, cid, <<>>} <- from_binary(bytes), do: {:ok, cid}
  end

  def from_link(_other), do: {:error, :invalid_cid_link}

  @doc """
  Parses a base32 multibase CID string (`b` prefix), the inverse of
  `to_string/1`.
  """
  @spec from_string(String.t()) :: {:ok, t} | {:error, atom | tuple}
  def from_string("b" <> encoded) do
    with {:ok, binary} <- decode_base32(encoded),
         {:ok, cid, <<>>} <- from_binary(binary) do
      {:ok, cid}
    else
      {:ok, _cid, _rest} -> {:error, :invalid_cid_string}
      {:error, reason} -> {:error, reason}
    end
  end

  def from_string(_other), do: {:error, :invalid_cid_string}

  defp decode_base32(encoded) do
    case Base.decode32(encoded, case: :lower, padding: false) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_cid_string}
    end
  end

  @doc """
  Re-encodes the CID to its binary form.
  """
  @spec to_binary(t) :: binary
  def to_binary(%__MODULE__{version: 1, codec: codec, multihash: multihash}) do
    <<1>> <> Varint.encode(codec) <> multihash
  end

  @doc """
  Encodes the CID in its base32 multibase string form (`b` prefix).
  """
  @spec to_string(t) :: String.t()
  def to_string(%__MODULE__{} = cid) do
    "b" <> Base.encode32(to_binary(cid), case: :lower, padding: false)
  end

  # multihash: hash function code varint <> digest size varint <> digest
  defp read_multihash(data) do
    with {:ok, code, rest} <- Varint.read(data),
         {:ok, size, rest} <- Varint.read(rest),
         {:ok, digest, rest} <- take(rest, size) do
      {:ok, Varint.encode(code) <> Varint.encode(size) <> digest, rest}
    end
  end

  defp take(rest, size) when byte_size(rest) >= size do
    <<digest::binary-size(^size), rest::binary>> = rest
    {:ok, digest, rest}
  end

  defp take(_rest, _size), do: {:error, :unexpected_end}

  defimpl String.Chars do
    def to_string(cid), do: ProtoRune.CID.to_string(cid)
  end
end
