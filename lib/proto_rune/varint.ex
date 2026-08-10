defmodule ProtoRune.Varint do
  @moduledoc """
  Unsigned LEB128 variable-length integer encoding.

  Used internally to read CAR files and CID values from the ATProto event
  stream, where lengths and codec identifiers are varint-prefixed.
  """

  import Bitwise

  @doc """
  Reads a varint from the head of the given binary.

  Returns the decoded integer along with the unconsumed rest of the input.
  """
  @spec read(binary) :: {:ok, non_neg_integer, binary} | {:error, atom}
  def read(binary), do: read(binary, 0, 0)

  defp read(<<0::1, chunk::7, rest::binary>>, acc, shift) when shift < 64, do: {:ok, acc ||| chunk <<< shift, rest}

  defp read(<<1::1, chunk::7, rest::binary>>, acc, shift) when shift < 64 do
    read(rest, acc ||| chunk <<< shift, shift + 7)
  end

  defp read(_binary, _acc, _shift), do: {:error, :invalid_varint}

  @doc """
  Encodes a non-negative integer as a varint.
  """
  @spec encode(non_neg_integer) :: binary
  def encode(value) when is_integer(value) and value >= 0 do
    if value < 0x80 do
      <<value>>
    else
      <<1::1, value::7>> <> encode(value >>> 7)
    end
  end
end
