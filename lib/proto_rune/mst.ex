defmodule ProtoRune.MST do
  @moduledoc """
  Traversal of and proofs over the Merkle Search Tree inside a repository
  checkout.

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

  Keys are prefix-compressed within each node: an entry's full key is the
  first `p` bytes of the previous key *in the same node* concatenated with
  `k`, and a node's first entry always stores its full key (`p` of 0).
  Traversal is depth-first in-order (left subtree, then each entry followed
  by its right subtree `t`), which yields entries in sorted key order.

  The MST root CID is the `data` field of the commit block, itself found
  under the CAR header's root CID (see `ProtoRune.CAR.read/1`).

  ## Proofs

  Because every node is content-addressed, the chain of nodes from the root
  down to a key proves that key's inclusion (or absence): an attacker can
  neither swap a node without breaking the CID chain nor invent a path the
  root does not commit to. `prove/3` extracts that chain from a complete
  checkout as a minimal partial tree, and `verify_proof/3` checks a claim
  against such a slice. `verify_ops/3` builds on this to verify the
  operations of a firehose commit event against the event's new MST root.

  ## Trust model

  This module performs no hashing and no signature checks: the CID-keyed
  block maps it walks are trusted as decoded. A proof is only as strong as
  the root CID it is anchored to — take the root from a commit verified
  with `ProtoRune.Atproto.Sync.verify_checkout/2` or
  `ProtoRune.Commit.verify/2`, and when the blocks come from an untrusted
  source, check that each block's bytes hash to its CID (as
  `verify_checkout/2` does for full checkouts).
  """

  alias ProtoRune.CID

  @typedoc "A decoded block map as returned by `ProtoRune.Atproto.Sync.parse_car/1`."
  @type blocks :: %{CID.t() => term()}

  @typedoc """
  A repository operation, as carried by firehose commit events.

    * `:action` - `:create`, `:update` or `:delete`.
    * `:path` - the record path, e.g. `"app.bsky.feed.post/3jxfb3nkkf22v"`.
    * `:cid` - the record CID (`nil` for deletions).
  """
  @type op :: %{action: :create | :update | :delete, path: String.t(), cid: CID.t() | nil}

  @typedoc """
  An inclusion or absence proof for a key.

    * `:key` - the proven `collection/rkey` key.
    * `:cid` - the record CID the key maps to, or `nil` when the key is
      absent from the tree.
    * `:nodes` - the MST node CIDs along the search path, root first.
      `Map.take(blocks, proof.nodes)` extracts the minimal partial tree
      that proves the claim.
  """
  @type proof :: %{key: String.t(), cid: CID.t() | nil, nodes: [CID.t()]}

  @doc """
  Enumerates the MST entries reachable from the given root CID.

  `root_cid` is the CID from the commit block's `data` field. Returns
  `{:ok, [{key, cid}]}` with the full `collection/rkey` key strings in
  sorted order, or `{:error, {:missing_block, cid}}` when the checkout is
  malformed and a referenced node block is absent.
  """
  @spec entries(blocks(), CID.t()) :: {:ok, [{String.t(), CID.t()}]} | {:error, tuple()}
  def entries(blocks, %CID{} = root_cid) when is_map(blocks) do
    case walk(blocks, root_cid, []) do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
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

  @doc """
  Builds an inclusion or absence proof for `key` from a complete block map.

  Walks the tree top-down from `root_cid`, collecting the node CIDs along
  the search path. The returned `proof.nodes` identify the minimal partial
  tree that proves the claim to a verifier that only knows the (trusted)
  root CID:

      {:ok, proof} = MST.prove(blocks, root_cid, "com.example.post/aaa2")
      slice = Map.take(blocks, proof.nodes)
      {:ok, {:included, cid}} = MST.verify_proof(slice, root_cid, proof.key)
  """
  @spec prove(blocks(), CID.t(), String.t()) :: {:ok, proof()} | {:error, tuple()}
  def prove(blocks, %CID{} = root_cid, key) when is_map(blocks) and is_binary(key) do
    case search(blocks, root_cid, key, []) do
      {:found, cid, path} -> {:ok, %{key: key, cid: cid, nodes: Enum.reverse(path)}}
      {:absent, path} -> {:ok, %{key: key, cid: nil, nodes: Enum.reverse(path)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies an inclusion or absence claim for `key` against a partial tree.

  `blocks` needs to contain only the nodes along the search path, such as
  a proof slice produced by `prove/3` or the CAR slice carried by a
  firehose commit event. Returns:

    * `{:ok, {:included, cid}}` - the key is present and maps to `cid`.
    * `{:ok, :absent}` - the search reached a null subtree pointer where
      the key would have to live, proving it is not in the tree.
    * `{:error, {:missing_block, cid}}` - the slice lacks a node needed to
      decide, so nothing can be concluded.
  """
  @spec verify_proof(blocks(), CID.t(), String.t()) ::
          {:ok, {:included, CID.t()} | :absent} | {:error, tuple()}
  def verify_proof(blocks, %CID{} = root_cid, key) when is_map(blocks) and is_binary(key) do
    case search(blocks, root_cid, key, []) do
      {:found, cid, _path} -> {:ok, {:included, cid}}
      {:absent, _path} -> {:ok, :absent}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies the ops of a firehose commit event against its new MST root.

  Each op's `path` is proven against `root_cid` using only the given
  blocks: `:create` and `:update` ops must be included with the claimed
  record CID, and `:delete` ops must be absent. Returns `:ok` when every
  op verifies, or `{:error, {path, reason}}` for the first op that does
  not, where `reason` is `:not_included`, `{:cid_mismatch, claimed, actual}`,
  `{:still_present, cid}` or `{:missing_block, cid}`.

  The proof ties the ops to `root_cid` only; take the root from a commit
  whose signature was verified (see `ProtoRune.Commit.verify/2`).
  `ProtoRune.Firehose.Event` blocks are keyed by CID string — convert them
  with `ProtoRune.CID.from_string/1` before calling:

      blocks =
        Map.new(event.blocks, fn {cid, block} ->
          {:ok, cid} = CID.from_string(cid)
          {cid, block}
        end)

      {:ok, root} = CID.from_link(commit["data"])
      :ok = MST.verify_ops(blocks, root, event.ops)
  """
  @spec verify_ops(blocks(), CID.t(), [op()]) :: :ok | {:error, {String.t(), term()}}
  def verify_ops(blocks, %CID{} = root_cid, ops) when is_map(blocks) and is_list(ops) do
    Enum.reduce_while(ops, :ok, fn op, :ok ->
      case verify_op(blocks, root_cid, op) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {op.path, reason}}}
      end
    end)
  end

  defp verify_op(blocks, root_cid, %{action: :delete, path: path}) do
    case verify_proof(blocks, root_cid, path) do
      {:ok, :absent} -> :ok
      {:ok, {:included, cid}} -> {:error, {:still_present, cid}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_op(blocks, root_cid, %{action: action, path: path, cid: cid}) when action in [:create, :update] do
    case verify_proof(blocks, root_cid, path) do
      {:ok, {:included, ^cid}} -> :ok
      {:ok, {:included, actual}} -> {:error, {:cid_mismatch, cid, actual}}
      {:ok, :absent} -> {:error, :not_included}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_records(_blocks, [], records), do: {:ok, records}

  defp resolve_records(blocks, [{key, cid} | rest], records) do
    case Map.fetch(blocks, cid) do
      {:ok, record} -> resolve_records(blocks, rest, Map.put(records, key, record))
      :error -> {:error, {:missing_block, cid}}
    end
  end

  # Depth-first in-order walk accumulating entries in reverse order.
  defp walk(blocks, cid, acc) do
    with {:ok, node} <- fetch_node(blocks, cid),
         {:ok, acc} <- walk_child(blocks, node["l"], acc) do
      walk_entries(blocks, Map.get(node, "e", []), "", acc)
    end
  end

  defp walk_child(_blocks, nil, acc), do: {:ok, acc}

  defp walk_child(blocks, link, acc) do
    with {:ok, cid} <- CID.from_link(link), do: walk(blocks, cid, acc)
  end

  defp walk_entries(_blocks, [], _last_key, acc), do: {:ok, acc}

  defp walk_entries(blocks, [entry | rest], last_key, acc) do
    with {:ok, cid} <- CID.from_link(entry["v"]),
         {:ok, key} <- reconstruct_key(last_key, entry["p"], entry["k"]),
         {:ok, acc} <- walk_child(blocks, entry["t"], [{key, cid} | acc]) do
      walk_entries(blocks, rest, key, acc)
    end
  end

  # Top-down search for `key`, collecting the visited node CIDs (root
  # last; callers reverse). Key reconstruction is local to each node, so a
  # node can be read without any context from its ancestors: the search
  # only needs the blocks along the path it actually descends.
  defp search(blocks, cid, key, path) do
    with {:ok, node} <- fetch_node(blocks, cid),
         {:ok, left} <- from_nullable_link(node["l"]),
         {:ok, entries} <- node_entries(node) do
      descend(blocks, left, entries, key, [cid | path])
    end
  end

  # The first entry with a key greater than or equal to the target decides:
  # equality means found; a greater key sends the search into the subtree
  # to that entry's left (the node's `l` for the first entry, the previous
  # entry's `t` otherwise); no such entry sends it past the last one.
  defp descend(blocks, left, [], key, path), do: descend_child(blocks, left, key, path)

  defp descend(blocks, left, entries, key, path) do
    case Enum.find_index(entries, fn {entry_key, _cid, _t} -> entry_key >= key end) do
      nil ->
        {_key, _cid, t} = List.last(entries)
        descend_child(blocks, t, key, path)

      index ->
        {entry_key, cid, _t} = Enum.at(entries, index)

        cond do
          entry_key == key ->
            {:found, cid, path}

          index == 0 ->
            descend_child(blocks, left, key, path)

          true ->
            {_key, _cid, t} = Enum.at(entries, index - 1)
            descend_child(blocks, t, key, path)
        end
    end
  end

  defp descend_child(_blocks, nil, _key, path), do: {:absent, path}
  defp descend_child(blocks, %CID{} = cid, key, path), do: search(blocks, cid, key, path)

  defp node_entries(node), do: decode_entries(Map.get(node, "e", []), "", [])

  defp decode_entries([], _last_key, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_entries([entry | rest], last_key, acc) do
    with {:ok, cid} <- CID.from_link(entry["v"]),
         {:ok, key} <- reconstruct_key(last_key, entry["p"], entry["k"]),
         {:ok, t} <- from_nullable_link(entry["t"]) do
      decode_entries(rest, key, [{key, cid, t} | acc])
    end
  end

  defp from_nullable_link(nil), do: {:ok, nil}
  defp from_nullable_link(link), do: CID.from_link(link)

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
