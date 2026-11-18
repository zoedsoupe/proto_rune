defmodule ProtoRune.MST.Inversion do
  @moduledoc false

  import Bitwise

  alias ProtoRune.CBOR
  alias ProtoRune.CID

  @doc false
  def verify(_blocks, _new_root, nil, _ops), do: {:error, :missing_prev_data}

  def verify(_blocks, %CID{} = new_root, %CID{} = previous_root, []) do
    if new_root == previous_root do
      :ok
    else
      {:error, {:root_mismatch, previous_root, new_root}}
    end
  end

  def verify(blocks, %CID{} = new_root, %CID{} = previous_root, ops) when is_map(blocks) and is_list(ops) do
    with :ok <- validate_prev_fields(ops),
         :ok <- validate_unique_paths(ops),
         {:ok, root_level} <- root_level_for_ops(blocks, new_root, ops),
         :ok <- validate_current_ops(blocks, new_root, root_level, ops),
         {:ok, computed_root, _changed_blocks} <-
           invert_ops(blocks, new_root, root_level, Enum.reverse(ops)) do
      if computed_root == previous_root do
        :ok
      else
        {:error, {:root_mismatch, previous_root, computed_root}}
      end
    end
  end

  @doc false
  def empty_tree do
    persist_root(%{keys: [], children: [nil]}, %{})
  end

  @doc false
  def put_record(blocks, %CID{} = root, key, %CID{} = value) when is_map(blocks) do
    with {:ok, height} <- root_level(blocks, root),
         {:ok, result, blocks} <-
           put_root(blocks, root, key, value, key_height(key), height) do
      normalize_root(blocks, result)
    end
  end

  @doc false
  def delete_record(blocks, %CID{} = root, key) when is_map(blocks) do
    with {:ok, height} <- root_level(blocks, root),
         {:ok, result, blocks} <-
           delete_at(blocks, root, key, key_height(key), height, nil, nil),
         {:ok, result, result_level} <- squash_root(blocks, result, height) do
      normalize_root(blocks, result, result_level)
    end
  end

  defp validate_current_ops(blocks, root, level, ops) do
    Enum.reduce_while(ops, :ok, fn op, :ok ->
      case validate_current_op(blocks, root, level, op) do
        :ok -> {:cont, :ok}
        {:error, {path, reason}} -> {:halt, {:error, {path, reason}}}
      end
    end)
  end

  defp validate_prev_fields(ops) do
    Enum.reduce_while(ops, :ok, fn
      %{action: action, path: path, prev: %CID{}}, :ok
      when action in [:update, :delete] and is_binary(path) ->
        {:cont, :ok}

      %{action: :create, path: path}, :ok when is_binary(path) ->
        {:cont, :ok}

      %{action: action, path: path}, :ok
      when action in [:update, :delete] and is_binary(path) ->
        {:halt, {:error, {path, :missing_prev}}}

      %{path: path}, :ok when is_binary(path) ->
        {:halt, {:error, {path, :invalid_op}}}

      _op, :ok ->
        {:halt, {:error, {"", :invalid_op}}}
    end)
  end

  defp validate_unique_paths(ops) do
    result =
      Enum.reduce_while(ops, {:ok, MapSet.new()}, fn %{path: path}, {:ok, seen} ->
        if MapSet.member?(seen, path) do
          {:halt, {:error, {path, :duplicate_operation}}}
        else
          {:cont, {:ok, MapSet.put(seen, path)}}
        end
      end)

    case result do
      {:ok, _seen} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp root_level_for_ops(blocks, root, [%{path: path} | _rest]) when is_binary(path) do
    case root_level(blocks, root) do
      {:ok, level} -> {:ok, level}
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp root_level_for_ops(blocks, root, _ops), do: root_level(blocks, root)

  defp validate_current_op(blocks, root, level, %{action: action, path: path, cid: claimed})
       when action in [:create, :update] and is_binary(path) do
    with :ok <- validate_key(path),
         {:ok, actual} <- search(blocks, root, path, level) do
      case actual do
        {:found, ^claimed} -> :ok
        {:found, actual} -> {:error, {path, {:cid_mismatch, claimed, actual}}}
        :absent -> {:error, {path, :not_included}}
      end
    else
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp validate_current_op(blocks, root, level, %{action: :delete, path: path}) when is_binary(path) do
    with :ok <- validate_key(path),
         {:ok, actual} <- search(blocks, root, path, level) do
      case actual do
        :absent -> :ok
        {:found, cid} -> {:error, {path, {:still_present, cid}}}
      end
    else
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp validate_current_op(_blocks, _root, _level, %{path: path}) when is_binary(path), do: {:error, {path, :invalid_op}}

  defp validate_current_op(_blocks, _root, _level, _op), do: {:error, {"", :invalid_op}}

  defp invert_ops(blocks, root, _level, []), do: {:ok, root, blocks}

  defp invert_ops(blocks, root, _level, [op | rest]) do
    path = Map.get(op, :path, "")

    with {:ok, root_level} <- root_level(blocks, root),
         {:ok, root, blocks} <- invert_op(blocks, root, root_level, op) do
      invert_ops(blocks, root, root_level, rest)
    else
      {:error, {^path, reason}} -> {:error, {path, reason}}
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp invert_op(blocks, root, _level, %{action: :create, path: path}) do
    case delete_record(blocks, root, path) do
      {:ok, root, blocks} -> {:ok, root, blocks}
      {:error, reason} -> {:error, reason}
    end
  end

  defp invert_op(blocks, root, _level, %{action: :update, path: path, prev: %CID{} = prev}) do
    case put_record(blocks, root, path, prev) do
      {:ok, root, blocks} -> {:ok, root, blocks}
      {:error, reason} -> {:error, reason}
    end
  end

  defp invert_op(blocks, root, _level, %{action: :delete, path: path, prev: %CID{} = prev}) do
    case put_record(blocks, root, path, prev) do
      {:ok, root, blocks} -> {:ok, root, blocks}
      {:error, reason} -> {:error, reason}
    end
  end

  defp invert_op(_blocks, _root, _level, %{action: action, path: path}) when action in [:update, :delete],
    do: {:error, {path, :missing_prev}}

  defp invert_op(_blocks, _root, _level, %{path: path}), do: {:error, {path, :invalid_op}}
  defp invert_op(_blocks, _root, _level, _op), do: {:error, {"", :invalid_op}}

  defp search(blocks, root, key, level) do
    search_at(blocks, root, key, level, nil, nil)
  end

  defp search_at(blocks, cid, key, level, lower, upper) do
    with {:ok, node} <- load_node(blocks, cid, level, lower, upper) do
      case lower_bound(node.keys, key) do
        {:found, {_key, value}, _index} ->
          {:ok, {:found, value}}

        {:child, index} ->
          search_child(blocks, node, key, level, index, lower, upper)
      end
    end
  end

  defp search_child(blocks, node, key, level, index, lower, upper) do
    case Enum.at(node.children, index) do
      nil ->
        {:ok, :absent}

      child ->
        search_at(
          blocks,
          child,
          key,
          level - 1,
          child_lower(node.keys, index, lower),
          child_upper(node.keys, index, upper)
        )
    end
  end

  defp put_at(blocks, nil, key, value, height, level, lower, upper) do
    put_into_empty(blocks, key, value, height, level, lower, upper)
  end

  defp put_at(blocks, cid, key, value, height, level, lower, upper) do
    with {:ok, node} <- load_node(blocks, cid, level, lower, upper) do
      cond do
        height > level ->
          grow_and_put(blocks, cid, key, value, height, level, {lower, upper})

        height < level ->
          {:child, index} = lower_bound(node.keys, key)
          put_below(blocks, node, key, value, height, level, index, {lower, upper})

        true ->
          put_here(blocks, cid, node, key, value, level, lower, upper)
      end
    end
  end

  defp grow_and_put(blocks, cid, key, value, height, level, {lower, upper}) do
    with {:ok, wrapper, blocks} <- persist_node(%{keys: [], children: [cid]}, blocks) do
      put_at(blocks, wrapper, key, value, height, level + 1, lower, upper)
    end
  end

  defp put_below(blocks, node, key, value, height, level, index, {lower, upper}) do
    child = Enum.at(node.children, index)

    with {:ok, updated, blocks} <-
           put_at(
             blocks,
             child,
             key,
             value,
             height,
             level - 1,
             child_lower(node.keys, index, lower),
             child_upper(node.keys, index, upper)
           ) do
      persist_optional(put_child(node, index, updated), blocks)
    end
  end

  defp put_root(blocks, root, key, value, height, level) do
    with {:ok, node} <- fetch_decoded_node(blocks, root) do
      case node do
        %{keys: [], children: [nil]} ->
          put_into_empty(blocks, key, value, height, height, nil, nil)

        _node ->
          put_at(blocks, root, key, value, height, level, nil, nil)
      end
    end
  end

  defp put_into_empty(blocks, key, value, height, level, lower, upper) when height < level do
    with {:ok, child, blocks} <-
           put_into_empty(blocks, key, value, height, level - 1, lower, upper) do
      persist_optional(%{keys: [], children: [child]}, blocks)
    end
  end

  defp put_into_empty(blocks, key, value, height, height, _lower, _upper) do
    persist_optional(%{keys: [{key, value}], children: [nil, nil]}, blocks)
  end

  defp put_into_empty(_blocks, _key, _value, height, level, _lower, _upper) when height > level,
    do: {:error, :invalid_key_depth}

  defp put_here(blocks, cid, node, key, value, level, lower, upper) do
    case lower_bound(node.keys, key) do
      {:found, {_key, ^value}, _index} ->
        {:ok, cid, blocks}

      {:found, _entry, index} ->
        updated = put_value(node, index, value)
        persist_node(updated, blocks)

      {:child, index} ->
        child = Enum.at(node.children, index)
        child_lower = child_lower(node.keys, index, lower)
        child_upper = child_upper(node.keys, index, upper)

        with {:ok, left, right, blocks} <-
               split_on_key(blocks, child, key, level - 1, child_lower, child_upper) do
          updated = insert_entry(node, index, key, value, left, right)
          persist_node(updated, blocks)
        end
    end
  end

  defp split_on_key(blocks, nil, _key, _level, _lower, _upper), do: {:ok, nil, nil, blocks}

  defp split_on_key(blocks, cid, key, level, lower, upper) do
    with {:ok, node} <- load_node(blocks, cid, level, lower, upper) do
      {:child, index} = lower_bound(node.keys, key)
      child = Enum.at(node.children, index)

      with {:ok, left_child, right_child, blocks} <-
             split_on_key(
               blocks,
               child,
               key,
               level - 1,
               child_lower(node.keys, index, lower),
               child_upper(node.keys, index, upper)
             ),
           left_node = %{
             keys: Enum.take(node.keys, index),
             children: Enum.take(node.children, index) ++ [left_child]
           },
           right_node = %{
             keys: Enum.drop(node.keys, index),
             children: [right_child | Enum.drop(node.children, index + 1)]
           },
           {:ok, left, blocks} <- persist_optional(left_node, blocks),
           {:ok, right, blocks} <- persist_optional(right_node, blocks) do
        {:ok, left, right, blocks}
      end
    end
  end

  defp delete_at(blocks, nil, _key, _height, _level, _lower, _upper), do: {:ok, nil, blocks}

  defp delete_at(blocks, cid, key, height, level, lower, upper) do
    if height > level do
      {:ok, cid, blocks}
    else
      delete_from_node(blocks, cid, key, height, level, lower, upper)
    end
  end

  defp delete_from_node(blocks, cid, key, height, level, lower, upper) do
    with {:ok, node} <- load_node(blocks, cid, level, lower, upper) do
      case lower_bound(node.keys, key) do
        {:child, index} when height < level ->
          delete_child(blocks, node, key, height, level, index, {lower, upper})

        {:found, _entry, index} when height == level ->
          delete_found(blocks, node, index, level, {lower, upper})

        _other ->
          {:ok, cid, blocks}
      end
    end
  end

  defp delete_child(blocks, node, key, height, level, index, {lower, upper}) do
    with {:ok, updated, blocks} <-
           delete_at(
             blocks,
             Enum.at(node.children, index),
             key,
             height,
             level - 1,
             child_lower(node.keys, index, lower),
             child_upper(node.keys, index, upper)
           ) do
      persist_optional(put_child(node, index, updated), blocks)
    end
  end

  defp delete_found(blocks, node, index, level, {lower, upper}) do
    pivot = elem(Enum.at(node.keys, index), 0)
    left = Enum.at(node.children, index)
    right = Enum.at(node.children, index + 1)

    with {:ok, merged, blocks} <-
           merge(
             blocks,
             left,
             right,
             level - 1,
             child_lower(node.keys, index, lower),
             pivot,
             child_upper(node.keys, index + 1, upper)
           ) do
      keys = List.delete_at(node.keys, index)
      children = List.replace_at(List.delete_at(node.children, index), index, merged)
      persist_optional(%{keys: keys, children: children}, blocks)
    end
  end

  defp merge(blocks, nil, right, _level, _lower, _pivot, _upper), do: {:ok, right, blocks}
  defp merge(blocks, left, nil, _level, _lower, _pivot, _upper), do: {:ok, left, blocks}

  defp merge(blocks, left, right, level, lower, pivot, upper) do
    with {:ok, left_node} <- load_node(blocks, left, level, lower, pivot),
         {:ok, right_node} <- load_node(blocks, right, level, pivot, upper),
         left_index = length(left_node.children) - 1,
         {:ok, boundary, blocks} <-
           merge(
             blocks,
             Enum.at(left_node.children, left_index),
             hd(right_node.children),
             level - 1,
             child_lower(left_node.keys, left_index, lower),
             pivot,
             child_upper(right_node.keys, 0, upper)
           ),
         keys = left_node.keys ++ right_node.keys,
         children =
           Enum.take(left_node.children, left_index) ++
             [boundary] ++ Enum.drop(right_node.children, 1),
         :ok <- validate_merged_keys(keys) do
      case persist_optional(%{keys: keys, children: children}, blocks) do
        {:ok, cid, blocks} -> {:ok, cid, blocks}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp root_level(blocks, root) do
    with {:ok, node} <- fetch_decoded_node(blocks, root) do
      root_node_level(node)
    end
  end

  defp root_node_level(%{keys: [{key, _value} | _rest]} = node) do
    level = key_height(key)
    with :ok <- validate_node_context(node, level, nil, nil), do: {:ok, level}
  end

  defp root_node_level(%{keys: [], children: [nil]}), do: {:ok, 0}
  defp root_node_level(%{keys: []}), do: {:error, :invalid_tree_depth}

  defp load_node(blocks, cid, level, lower, upper) do
    with {:ok, node} <- fetch_decoded_node(blocks, cid),
         :ok <- validate_node_context(node, level, lower, upper) do
      {:ok, node}
    end
  end

  defp fetch_decoded_node(blocks, cid) do
    case Map.fetch(blocks, cid) do
      {:ok, raw} when is_map(raw) -> decode_node(raw)
      {:ok, _other} -> {:error, {:invalid_node, cid}}
      :error -> {:error, {:missing_block, cid}}
    end
  end

  defp decode_node(%{"l" => left, "e" => entries} = raw) when is_list(entries) and map_size(raw) == 2 do
    with {:ok, left} <- nullable_cid(left),
         {:ok, keys, children} <- decode_entries(entries, "", [left], []) do
      {:ok, %{keys: keys, children: children}}
    else
      {:error, _reason} = error -> error
    end
  end

  defp decode_node(_raw), do: {:error, :invalid_node}

  defp decode_entries([], _previous, children, keys), do: {:ok, Enum.reverse(keys), Enum.reverse(children)}

  defp decode_entries(
         [%{"p" => prefix, "k" => suffix, "v" => value_link, "t" => child_link} = entry | rest],
         previous,
         children,
         keys
       )
       when map_size(entry) == 4 do
    with true <- is_integer(prefix) and prefix >= 0 and prefix <= byte_size(previous),
         true <- is_binary(suffix),
         key = binary_part(previous, 0, prefix) <> suffix,
         :ok <- validate_key(key),
         :ok <- validate_prefix(prefix, previous, key),
         :ok <- validate_sort_order(key, previous),
         {:ok, value} <- CID.from_link(value_link),
         {:ok, child} <- nullable_cid(child_link) do
      decode_entries(rest, key, [child | children], [{key, value} | keys])
    else
      false when not is_integer(prefix) or prefix < 0 or prefix > byte_size(previous) ->
        {:error, :invalid_key_prefix}

      false ->
        {:error, :invalid_node}

      {:error, _reason} = error ->
        error
    end
  end

  defp decode_entries(_entries, _previous, _children, _keys), do: {:error, :invalid_node}

  defp validate_node_context(node, level, lower, upper) do
    Enum.reduce_while(node.keys, :ok, fn {key, _value}, :ok ->
      cond do
        key_height(key) != level ->
          {:halt, {:error, :invalid_key_depth}}

        not is_nil(lower) and key <= lower ->
          {:halt, {:error, :invalid_key_order}}

        not is_nil(upper) and key >= upper ->
          {:halt, {:error, :invalid_key_order}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_prefix(prefix, previous, key) do
    if prefix == common_prefix_length(previous, key),
      do: :ok,
      else: {:error, :noncanonical_key_prefix}
  end

  defp validate_sort_order(key, previous) do
    if key > previous, do: :ok, else: {:error, :invalid_key_order}
  end

  defp validate_key(key) when is_binary(key) and byte_size(key) in 3..1024 do
    if Regex.match?(~r/^[a-zA-Z0-9_~.:-]+\/[a-zA-Z0-9_~.:-]+$/, key),
      do: :ok,
      else: {:error, :invalid_mst_key}
  end

  defp validate_key(_key), do: {:error, :invalid_mst_key}

  defp nullable_cid(nil), do: {:ok, nil}
  defp nullable_cid(link), do: CID.from_link(link)

  defp lower_bound(keys, key), do: lower_bound(keys, key, 0)

  defp lower_bound([], _key, index), do: {:child, index}

  defp lower_bound([{entry_key, _value} = entry | rest], key, index) do
    cond do
      entry_key == key -> {:found, entry, index}
      entry_key > key -> {:child, index}
      true -> lower_bound(rest, key, index + 1)
    end
  end

  defp child_lower(_keys, index, lower) when index == 0, do: lower
  defp child_lower(keys, index, _lower), do: keys |> Enum.at(index - 1) |> elem(0)

  defp child_upper(keys, index, upper) when index == length(keys), do: upper
  defp child_upper(keys, index, _upper), do: keys |> Enum.at(index) |> elem(0)

  defp put_child(node, index, child), do: %{node | children: List.replace_at(node.children, index, child)}

  defp put_value(node, index, value),
    do: %{node | keys: List.replace_at(node.keys, index, {elem(Enum.at(node.keys, index), 0), value})}

  defp insert_entry(node, index, key, value, left, right) do
    %{
      keys: List.insert_at(node.keys, index, {key, value}),
      children:
        node.children
        |> List.replace_at(index, left)
        |> List.insert_at(index + 1, right)
    }
  end

  defp persist_optional(%{keys: [], children: [nil]}, blocks), do: {:ok, nil, blocks}
  defp persist_optional(node, blocks), do: persist_node(node, blocks)

  defp persist_root(node, blocks), do: persist_node(node, blocks)

  defp persist_node(%{keys: keys, children: children}, blocks) when length(children) == length(keys) + 1 do
    entries =
      keys
      |> Enum.with_index()
      |> Enum.map(fn {{key, value}, index} ->
        previous = if index == 0, do: "", else: elem(Enum.at(keys, index - 1), 0)
        prefix = common_prefix_length(previous, key)

        %{
          "p" => prefix,
          "k" => CBOR.bytes(binary_part(key, prefix, byte_size(key) - prefix)),
          "v" => link(value),
          "t" => link_or_nil(Enum.at(children, index + 1))
        }
      end)

    raw = %{"l" => link_or_nil(hd(children)), "e" => entries}
    bytes = CBOR.encode(raw)
    cid = CID.from_dag_cbor(bytes)

    case CBOR.decode(bytes) do
      {:ok, decoded, <<>>} -> {:ok, cid, Map.put(blocks, cid, decoded)}
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_node}
    end
  end

  defp persist_node(_node, _blocks), do: {:error, :invalid_node}

  defp normalize_root(blocks, nil), do: persist_root(%{keys: [], children: [nil]}, blocks)
  defp normalize_root(blocks, cid), do: {:ok, cid, blocks}

  defp normalize_root(blocks, nil, _level), do: persist_root(%{keys: [], children: [nil]}, blocks)
  defp normalize_root(blocks, cid, _level), do: {:ok, cid, blocks}

  defp squash_root(_blocks, nil, _level), do: {:ok, nil, 0}

  defp squash_root(blocks, cid, level) do
    with {:ok, node} <- load_node(blocks, cid, level, nil, nil) do
      case node do
        %{keys: [], children: [child]} when not is_nil(child) ->
          squash_child(blocks, child, level - 1)

        _node ->
          {:ok, cid, level}
      end
    end
  end

  defp squash_child(blocks, child, level) do
    case Map.fetch(blocks, child) do
      {:ok, _node} -> squash_root(blocks, child, level)
      :error -> {:ok, child, level}
    end
  end

  defp key_height(key) do
    hash = :crypto.hash(:sha256, key)
    hash |> leading_zero_bits(0) |> div(2)
  end

  defp leading_zero_bits(<<0, rest::binary>>, count), do: leading_zero_bits(rest, count + 8)

  defp leading_zero_bits(<<byte, _rest::binary>>, count) do
    count + leading_zeros_in_byte(byte, 7)
  end

  defp leading_zero_bits(<<>>, count), do: count

  defp leading_zeros_in_byte(byte, bit) when bit >= 0 do
    if band(byte, 1 <<< bit) == 0, do: leading_zeros_in_byte(byte, bit - 1), else: 7 - bit
  end

  defp leading_zeros_in_byte(_byte, _bit), do: 8

  defp common_prefix_length(left, right), do: common_prefix_length(left, right, 0)

  defp common_prefix_length(<<byte, left::binary>>, <<byte, right::binary>>, count),
    do: common_prefix_length(left, right, count + 1)

  defp common_prefix_length(_left, _right, count), do: count

  defp validate_merged_keys(keys) do
    if keys
       |> Enum.chunk_every(2, 1, :discard)
       |> Enum.all?(fn [{left, _}, {right, _}] -> left < right end) do
      :ok
    else
      {:error, :invalid_key_order}
    end
  end

  defp link(%CID{} = cid), do: {:tag, 42, <<0, CID.to_binary(cid)::binary>>}
  defp link_or_nil(nil), do: nil
  defp link_or_nil(%CID{} = cid), do: link(cid)
end
