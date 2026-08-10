defmodule ProtoRune.CAR do
  @moduledoc """
  Reader for CAR (Content Addressable aRchive) v1 data.

  Commit events delivered by the ATProto firehose carry their repository
  blocks as a CAR byte string in the `blocks` field. A CAR is a sequence of
  varint-length-prefixed segments: a CBOR header with the root CIDs, followed
  by entries pairing a binary CID with its block data.
  """

  alias ProtoRune.CBOR
  alias ProtoRune.CID
  alias ProtoRune.Varint

  @typedoc "A parsed CAR: the root CIDs and the ordered CID/block entries."
  @type t :: %{roots: [CID.t()], blocks: [{CID.t(), binary}]}

  @doc """
  Parses CAR data, returning its roots and blocks.

  Blocks are returned as `{cid, block_bytes}` tuples in archive order; the
  block bytes are the raw DAG-CBOR data, decodable with `ProtoRune.CBOR`.
  """
  @spec read(binary) :: {:ok, t} | {:error, atom | tuple}
  def read(data) when is_binary(data) do
    with {:ok, header_bytes, rest} <- read_segment(data),
         {:ok, header, <<>>} <- CBOR.decode(header_bytes),
         :ok <- validate_header(header),
         {:ok, roots} <- read_roots(header),
         {:ok, blocks} <- read_blocks(rest, []) do
      {:ok, %{roots: roots, blocks: blocks}}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_car_header}
    end
  end

  defp validate_header(%{"version" => 1}), do: :ok
  defp validate_header(%{"version" => version}), do: {:error, {:unsupported_car_version, version}}
  defp validate_header(_header), do: {:error, :invalid_car_header}

  defp read_roots(%{"roots" => roots}) when is_list(roots) do
    roots
    |> Enum.reduce_while({:ok, []}, fn link, {:ok, acc} ->
      case CID.from_link(link) do
        {:ok, cid} -> {:cont, {:ok, [cid | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, cids} -> {:ok, Enum.reverse(cids)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_roots(_header), do: {:error, :invalid_car_header}

  defp read_blocks(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp read_blocks(data, acc) do
    with {:ok, entry, rest} <- read_segment(data),
         {:ok, cid, block} <- CID.from_binary(entry) do
      read_blocks(rest, [{cid, block} | acc])
    end
  end

  defp read_segment(data) do
    with {:ok, length, rest} <- Varint.read(data) do
      take(rest, length)
    end
  end

  defp take(rest, size) when byte_size(rest) >= size do
    <<segment::binary-size(^size), rest::binary>> = rest
    {:ok, segment, rest}
  end

  defp take(_rest, _size), do: {:error, :unexpected_end}
end
