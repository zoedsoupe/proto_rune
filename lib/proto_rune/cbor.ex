defmodule ProtoRune.CBOR do
  @moduledoc """
  Minimal CBOR (RFC 8949) decoder.

  Covers the DAG-CBOR subset used by the ATProto event stream: unsigned and
  negative integers, byte and text strings, arrays, maps, semantic tags,
  booleans, null and 32/64-bit floats. Indefinite-length items, half floats
  and simple values are not valid DAG-CBOR and are rejected.

  Semantic tags are returned as `{:tag, number, value}` tuples. The tag 42
  (CID link) can be turned into a `ProtoRune.CID` with `ProtoRune.CID.from_link/1`.

  Decoding returns the value together with the unconsumed rest of the input,
  which allows decoding the concatenated header/payload pairs used by
  `com.atproto.sync.subscribeRepos` frames.
  """

  @typedoc "A CBOR semantic tag, e.g. `{:tag, 42, bytes}` for a CID link."
  @type tag :: {:tag, non_neg_integer, term}

  @doc """
  Decodes a single CBOR item from the head of the given binary.

  Returns the decoded term and the unconsumed rest of the input.
  """
  @spec decode(binary) :: {:ok, term, binary} | {:error, atom}
  def decode(<<>>), do: {:error, :unexpected_end}
  def decode(data), do: decode_value(data)

  # major type 0: unsigned integer
  defp decode_value(<<0::3, info::5, rest::binary>>), do: decode_argument(info, rest)

  # major type 1: negative integer
  defp decode_value(<<1::3, info::5, rest::binary>>) do
    with {:ok, value, rest} <- decode_argument(info, rest), do: {:ok, -1 - value, rest}
  end

  # major types 2 and 3: byte string and text string (both Elixir binaries)
  defp decode_value(<<major::3, info::5, rest::binary>>) when major in [2, 3] do
    with {:ok, length, rest} <- decode_argument(info, rest) do
      take(rest, length)
    end
  end

  # major type 4: array
  defp decode_value(<<4::3, info::5, rest::binary>>) do
    with {:ok, length, rest} <- decode_argument(info, rest),
         do: decode_list(rest, length, [])
  end

  # major type 5: map
  defp decode_value(<<5::3, info::5, rest::binary>>) do
    with {:ok, length, rest} <- decode_argument(info, rest),
         do: decode_map(rest, length, [])
  end

  # major type 6: semantic tag
  defp decode_value(<<6::3, info::5, rest::binary>>) do
    with {:ok, tag, rest} <- decode_argument(info, rest),
         {:ok, value, rest} <- decode_value(rest) do
      {:ok, {:tag, tag, value}, rest}
    end
  end

  # major type 7: booleans, null and floats
  defp decode_value(<<7::3, 20::5, rest::binary>>), do: {:ok, false, rest}
  defp decode_value(<<7::3, 21::5, rest::binary>>), do: {:ok, true, rest}
  defp decode_value(<<7::3, 22::5, rest::binary>>), do: {:ok, nil, rest}
  defp decode_value(<<7::3, 26::5, value::32-float, rest::binary>>), do: {:ok, value, rest}
  defp decode_value(<<7::3, 27::5, value::64-float, rest::binary>>), do: {:ok, value, rest}
  defp decode_value(<<7::3, _info::5, _rest::binary>>), do: {:error, :unsupported_simple_value}

  defp decode_argument(info, rest) when info < 24, do: {:ok, info, rest}
  defp decode_argument(24, <<value, rest::binary>>), do: {:ok, value, rest}
  defp decode_argument(25, <<value::16, rest::binary>>), do: {:ok, value, rest}
  defp decode_argument(26, <<value::32, rest::binary>>), do: {:ok, value, rest}
  defp decode_argument(27, <<value::64, rest::binary>>), do: {:ok, value, rest}
  defp decode_argument(info, _rest) when info in 28..30, do: {:error, :reserved_argument}
  defp decode_argument(31, _rest), do: {:error, :indefinite_length}
  defp decode_argument(_info, _rest), do: {:error, :unexpected_end}

  defp decode_list(rest, 0, acc), do: {:ok, Enum.reverse(acc), rest}

  defp decode_list(data, remaining, acc) do
    with {:ok, value, rest} <- decode_value(data),
         do: decode_list(rest, remaining - 1, [value | acc])
  end

  defp decode_map(rest, 0, acc), do: {:ok, Map.new(acc), rest}

  defp decode_map(data, remaining, acc) do
    with {:ok, key, rest} <- decode_value(data),
         {:ok, value, rest} <- decode_value(rest) do
      decode_map(rest, remaining - 1, [{key, value} | acc])
    end
  end

  defp take(rest, length) when byte_size(rest) >= length do
    <<bytes::binary-size(^length), rest::binary>> = rest
    {:ok, bytes, rest}
  end

  defp take(_rest, _length), do: {:error, :unexpected_end}
end
