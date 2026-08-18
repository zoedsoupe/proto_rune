defmodule ProtoRune.MST do
  @moduledoc """
  Traversal of the Merkle Search Tree inside a repository checkout.

  A `com.atproto.sync.getRepo` CAR (see `ProtoRune.Atproto.Sync.get_repo/2`)
  contains the repository's MST as DAG-CBOR node blocks. Each node holds a
  nullable left subtree link `l` and an ordered list of entries `e`, where
  every entry maps a `collection/rkey` key to the CID of a record block:

      %{
        "l" => left_cid | nil,
        "e" => [
          %{"p" => prefix_len, "k" => key_suffix, "v" => record_cid, "t" => subtree_cid | nil}
        ]
      }

  Keys are prefix-compressed: an entry's full key is the first `p` bytes of
  the previous key in traversal order concatenated with `k`. Traversal is
  depth-first in-order (left subtree, then each entry followed by its right
  subtree `t`), which yields entries in sorted key order.

  The MST root CID is the `data` field of the commit block, itself found
  under the CAR header's root CID (see `ProtoRune.CAR.read/1`).

  ## Trust model

  This module performs no verification: no key hashing, no inclusion
  proofs, no diffing. The blocks are trusted as delivered by the source
  PDS, matching the trust model of `ProtoRune.Atproto.Sync`.
  """

  alias ProtoRune.CID

  @typedoc "A decoded block map as returned by `ProtoRune.Atproto.Sync.parse_car/1`."
  @type blocks :: %{CID.t() => term()}

  @doc """
  Enumerates the MST entries reachable from the given root CID.

  `root_cid` is the CID from the commit block's `data` field. Returns
  `{:ok, [{key, cid}]}` with the full `collection/rkey` key strings in
  sorted order, or `{:error, {:missing_block, cid}}` when the checkout is
  malformed and a referenced node block is absent.
  """
  @spec entries(blocks(), CID.t()) :: {:ok, [{String.t(), CID.t()}]} | {:error, tuple()}
  def entries(blocks, %CID{} = root_cid) when is_map(blocks) do
    case walk(blocks, root_cid, "", []) do
      {:ok, _last_key, acc} -> {:ok, Enum.reverse(acc)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Enumerates the records of a checkout, keyed by `collection/rkey`.

  Resolves each entry CID from `entries/2` against `blocks`, so MST node
  and commit blocks are not part of the result. Returns
  `{:error, {:missing_block, cid}}` when a referenced block is absent from
  the checkout.
  """
  @spec records(blocks(), CID.t()) :: {:ok, %{String.t() => term()}} | {:error, tuple()}
  def records(blocks, %CID{} = root_cid) when is_map(blocks) do
    with {:ok, entries} <- entries(blocks, root_cid) do
      resolve_records(blocks, entries, %{})
    end
  end

  defp resolve_records(_blocks, [], records), do: {:ok, records}

  defp resolve_records(blocks, [{key, cid} | rest], records) do
    case Map.fetch(blocks, cid) do
      {:ok, record} -> resolve_records(blocks, rest, Map.put(records, key, record))
      :error -> {:error, {:missing_block, cid}}
    end
  end

  # Depth-first in-order walk carrying the previous key (for prefix
  # compression) and the accumulated entries in reverse order.
  defp walk(blocks, cid, last_key, acc) do
    with {:ok, node} <- fetch_node(blocks, cid),
         {:ok, last_key, acc} <- walk_child(blocks, node["l"], last_key, acc) do
      walk_entries(blocks, Map.get(node, "e", []), last_key, acc)
    end
  end

  defp walk_child(_blocks, nil, last_key, acc), do: {:ok, last_key, acc}

  defp walk_child(blocks, link, last_key, acc) do
    with {:ok, cid} <- CID.from_link(link), do: walk(blocks, cid, last_key, acc)
  end

  defp walk_entries(_blocks, [], last_key, acc), do: {:ok, last_key, acc}

  defp walk_entries(blocks, [entry | rest], last_key, acc) do
    with {:ok, cid} <- CID.from_link(entry["v"]),
         {:ok, key} <- reconstruct_key(last_key, entry["p"], entry["k"]),
         {:ok, last_key, acc} <- walk_child(blocks, entry["t"], key, [{key, cid} | acc]) do
      walk_entries(blocks, rest, last_key, acc)
    end
  end

  defp reconstruct_key(last_key, prefix_len, suffix)
       when is_integer(prefix_len) and is_binary(suffix) and prefix_len <= byte_size(last_key) do
    {:ok, binary_part(last_key, 0, prefix_len) <> suffix}
  end

  defp reconstruct_key(_last_key, _prefix_len, _suffix), do: {:error, :invalid_key_prefix}

  defp fetch_node(blocks, cid) do
    case Map.fetch(blocks, cid) do
      {:ok, node} when is_map(node) -> {:ok, node}
      {:ok, _other} -> {:error, {:invalid_node, cid}}
      :error -> {:error, {:missing_block, cid}}
    end
  end
end
