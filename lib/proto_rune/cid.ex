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
  Decodes a DAG-CBOR CID link (`{:tag, 42, bytes}`) into a CID.

  DAG-CBOR prefixes the binary CID with a single `0x00` byte for historical
  multibase reasons.
  """
  @spec from_link(term) :: {:ok, t} | {:error, atom | tuple}
  def from_link({:tag, 42, <<0, bytes::binary>>}) do
    with {:ok, cid, <<>>} <- from_binary(bytes), do: {:ok, cid}
  end

  def from_link(_other), do: {:error, :invalid_cid_link}

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
