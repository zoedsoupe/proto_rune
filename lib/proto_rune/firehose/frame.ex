defmodule ProtoRune.Firehose.Frame do
  @moduledoc """
  Decodes firehose WebSocket frames into `ProtoRune.Firehose.Event` structs.

  Each frame received on `com.atproto.sync.subscribeRepos` is the
  concatenation of two CBOR objects: a header and a message-specific
  payload. Regular messages carry `%{"op" => 1, "t" => "#commit"}`-style
  headers, while `%{"op" => -1}` headers signal error frames.
  """

  alias ProtoRune.CAR
  alias ProtoRune.CBOR
  alias ProtoRune.CID
  alias ProtoRune.Firehose.Event

  @event_types %{
    "#commit" => :commit,
    "#identity" => :identity,
    "#account" => :account,
    "#handle" => :handle,
    "#migrate" => :migrate,
    "#tombstone" => :tombstone,
    "#info" => :info
  }

  @doc """
  Decodes a binary WebSocket frame into an event.
  """
  @spec decode(binary) :: {:ok, Event.t()} | {:error, atom | tuple}
  def decode(data) when is_binary(data) do
    with {:ok, header, rest} when is_map(header) <- CBOR.decode(data),
         {:ok, payload, _rest} when is_map(payload) <- CBOR.decode(rest) do
      build_event(header, payload)
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_frame}
    end
  end

  defp build_event(%{"op" => -1}, payload) do
    {:ok, %Event{type: :error, payload: payload}}
  end

  defp build_event(%{"op" => 1, "t" => "#commit"}, payload) do
    with {:ok, ops} <- decode_ops(payload["ops"] || []),
         {:ok, blocks} <- decode_blocks(payload["blocks"]) do
      {:ok,
       %Event{
         type: :commit,
         seq: payload["seq"],
         repo: payload["repo"],
         time: payload["time"],
         rev: payload["rev"],
         ops: ops,
         blocks: blocks,
         payload: payload
       }}
    end
  end

  defp build_event(%{"op" => 1, "t" => type}, payload) do
    {:ok,
     %Event{
       type: Map.get(@event_types, type, :unknown),
       seq: payload["seq"],
       repo: payload["did"] || payload["repo"],
       time: payload["time"],
       payload: payload
     }}
  end

  defp build_event(_header, _payload), do: {:error, :invalid_frame_header}

  defp decode_ops(ops) when is_list(ops) do
    ops
    |> Enum.reduce_while({:ok, []}, fn op, {:ok, acc} ->
      case decode_op(op) do
        {:ok, op} -> {:cont, {:ok, [op | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, ops} -> {:ok, Enum.reverse(ops)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_ops(_ops), do: {:error, :invalid_commit_ops}

  defp decode_op(%{"action" => action, "path" => path} = op) do
    with {:ok, cid} <- decode_link(op["cid"]) do
      {:ok, %{action: decode_action(action), path: path, cid: cid}}
    end
  end

  defp decode_op(_op), do: {:error, :invalid_commit_op}

  defp decode_action("create"), do: :create
  defp decode_action("update"), do: :update
  defp decode_action("delete"), do: :delete
  defp decode_action(action), do: action

  defp decode_link(nil), do: {:ok, nil}
  defp decode_link(link), do: CID.from_link(link)

  defp decode_blocks(nil), do: {:ok, %{}}

  defp decode_blocks(bytes) when is_binary(bytes) do
    with {:ok, car} <- CAR.read(bytes) do
      Enum.reduce_while(car.blocks, {:ok, %{}}, &decode_block/2)
    end
  end

  defp decode_blocks(_other), do: {:error, :invalid_commit_blocks}

  defp decode_block({cid, block}, {:ok, acc}) do
    case CBOR.decode(block) do
      {:ok, record, _rest} -> {:cont, {:ok, Map.put(acc, CID.to_string(cid), resolve_links(record))}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  # Turns every DAG-CBOR CID link inside a decoded record into a CID struct.
  defp resolve_links({:tag, 42, _bytes} = link) do
    case CID.from_link(link) do
      {:ok, cid} -> cid
      {:error, _reason} -> link
    end
  end

  defp resolve_links(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, resolve_links(value)} end)
  end

  defp resolve_links(list) when is_list(list), do: Enum.map(list, &resolve_links/1)
  defp resolve_links(value), do: value
end
