defmodule ProtoRune.Lexicon.TypeMapper do
  @moduledoc """
  Maps ATProto lexicon type definitions to Peri schema types.

  This module is the JSON-to-Peri translation engine used by
  `ProtoRune.Lexicon.Loader`. Its input is a lexicon type definition whose
  `$ref` graph has already been inlined by `ProtoRune.Lexicon.Resolver`: a
  `"ref"` node or a `"refs"`-only union node reaching `map_type/1` is a bug
  in the caller, and is reported as `{:unresolved_ref, _}` /
  `{:unresolved_union, _}` instead of silently emitting a Peri term that
  validates nothing.

  ## Supported ATProto Types

  - Primitives: string, integer, boolean, float, bytes
  - Complex: object, params, array, union
  - Special: unknown (maps to :any), token (maps to :string),
    cid-link and blob (map to :map)
  - Formats: datetime, uri, did, handle, etc.

  Property names become atoms via `String.to_atom/1`. The atom table grows
  once per distinct lexicon property name, bounded by the loaded lexicon
  corpus; keys keep the exact camelCase spelling the lexicon uses
  (`"createdAt"` becomes `:"createdAt"`), so validated records are
  atom-keyed wire shapes.

  ## Examples

      iex> TypeMapper.map_type(%{"type" => "string"})
      {:ok, :string}

      iex> TypeMapper.map_type(%{"type" => "integer"})
      {:ok, :integer}

      iex> TypeMapper.map_type(%{"type" => "array", "items" => %{"type" => "string"}})
      {:ok, {:list, :string}}
  """

  @type atproto_type :: map()
  @type peri_type :: atom() | tuple() | map()
  @type mapping_result :: {:ok, peri_type()} | {:error, term()}

  @doc """
  Maps an ATProto type definition to a Peri schema type.

  ## Parameters

  - `type_def`: A map containing the ATProto type definition, with all refs
    already inlined (see `ProtoRune.Lexicon.Resolver`)

  ## Returns

  - `{:ok, peri_type}` on success
  - `{:error, reason}` if mapping fails
  """
  @spec map_type(atproto_type()) :: mapping_result()
  def map_type(%{"type" => "string"} = def), do: map_string_type(def)
  def map_type(%{"type" => "integer"} = def), do: map_integer_type(def)
  def map_type(%{"type" => "float"} = def), do: map_float_type(def)
  def map_type(%{"type" => "boolean"}), do: {:ok, :boolean}
  def map_type(%{"type" => "bytes"}), do: {:ok, :string}
  def map_type(%{"type" => "unknown"}), do: {:ok, :any}
  def map_type(%{"type" => "blob"}), do: {:ok, :map}
  def map_type(%{"type" => "token"}), do: {:ok, :string}
  def map_type(%{"type" => "cid-link"}), do: {:ok, :map}

  def map_type(%{"type" => "array"} = def), do: map_array_type(def)

  # A ref to a record definition unwraps to the record's object body.
  def map_type(%{"type" => "record", "record" => body}), do: map_type(body)

  def map_type(%{"type" => "object"} = type_def), do: map_object_type(type_def)
  def map_type(%{"type" => "params"} = type_def), do: map_object_type(type_def)

  # The Resolver consumes every ref before translation. Reaching this clause
  # means a ref escaped resolution; emitting `{:ref, binary}` would produce a
  # Peri term that rejects everything, so it fails loudly instead.
  def map_type(%{"type" => "ref", "ref" => ref}), do: {:error, {:unresolved_ref, ref}}

  def map_type(%{"type" => "union"} = def), do: map_union_type(def)
  def map_type(%{"type" => _} = type_def), do: {:error, {:unsupported_type, type_def}}
  def map_type(_), do: {:error, :invalid_type_definition}

  @doc """
  Maps an object's properties to a Peri schema map.
  """
  @spec map_object_type(atproto_type()) :: mapping_result()
  def map_object_type(%{"properties" => properties, "required" => required})
      when is_map(properties) and is_list(required) do
    map_properties(properties, required)
  end

  def map_object_type(%{"properties" => properties}) when is_map(properties) do
    map_properties(properties, [])
  end

  # Objects and params with no declared properties accept any map shape
  # (strictly: an empty schema).
  def map_object_type(%{"type" => kind}) when kind in ["object", "params"], do: {:ok, %{}}

  def map_object_type(_), do: {:error, :invalid_object_definition}

  # Private functions

  # Peri's :datetime only accepts %DateTime{} structs, but record data carries
  # the ISO 8601 string the wire uses (the hand-written Repo schemas validate
  # `created_at` as a plain string for the same reason), so the format maps to
  # a plain string.
  defp map_string_type(%{"format" => "datetime"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "uri"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "did"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "handle"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "at-uri"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "at-identifier"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "cid"}), do: {:ok, :string}
  defp map_string_type(%{"format" => "language"}), do: {:ok, :string}

  defp map_string_type(%{"maxLength" => max, "minLength" => min}) do
    {:ok, {:string, [{:min, min}, {:max, max}]}}
  end

  defp map_string_type(%{"maxLength" => max}) do
    {:ok, {:string, {:max, max}}}
  end

  defp map_string_type(%{"minLength" => min}) do
    {:ok, {:string, {:min, min}}}
  end

  defp map_string_type(%{"enum" => values}) when is_list(values) do
    {:ok, {:enum, values}}
  end

  defp map_string_type(%{"const" => value}) do
    {:ok, {:literal, value}}
  end

  defp map_string_type(_), do: {:ok, :string}

  defp map_integer_type(%{"minimum" => min, "maximum" => max}) do
    {:ok, {:integer, {:range, {min, max}}}}
  end

  defp map_integer_type(%{"minimum" => min}) do
    {:ok, {:integer, {:gte, min}}}
  end

  defp map_integer_type(%{"maximum" => max}) do
    {:ok, {:integer, {:lte, max}}}
  end

  defp map_integer_type(%{"enum" => values}) when is_list(values) do
    {:ok, {:enum, values}}
  end

  defp map_integer_type(%{"const" => value}) do
    {:ok, {:literal, value}}
  end

  defp map_integer_type(_), do: {:ok, :integer}

  defp map_float_type(%{"minimum" => min, "maximum" => max}) do
    {:ok, {:float, {:range, {min, max}}}}
  end

  defp map_float_type(%{"minimum" => min}) do
    {:ok, {:float, {:gte, min}}}
  end

  defp map_float_type(%{"maximum" => max}) do
    {:ok, {:float, {:lte, max}}}
  end

  defp map_float_type(_), do: {:ok, :float}

  defp map_array_type(%{"items" => items} = def) do
    with {:ok, item_type} <- map_type(items) do
      {:ok, list_type(item_type, def)}
    end
  end

  defp map_array_type(_), do: {:error, :invalid_array_definition}

  defp list_type(item_type, def) do
    bounds =
      []
      |> maybe_bound({:max, def["maxLength"]})
      |> maybe_bound({:min, def["minLength"]})

    case bounds do
      [] -> {:list, item_type}
      opts -> {:list, item_type, opts}
    end
  end

  defp maybe_bound(acc, {_key, nil}), do: acc
  defp maybe_bound(acc, {key, value}), do: [{key, value} | acc]

  # The Resolver attaches the resolvable members of a union under "variants",
  # each already carrying the `$type` literal the wire data uses. The members
  # discriminate the oneof, so any data naming none of them is rejected.
  defp map_union_type(%{"variants" => variants}) when is_map(variants) do
    variants
    |> Map.values()
    |> Enum.reduce_while({:ok, []}, fn variant, {:ok, acc} ->
      case map_type(variant) do
        {:ok, type} -> {:cont, {:ok, [type | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      # Every member dangling or cyclic: the subtree stays unchecked.
      {:ok, []} -> {:ok, :any}
      {:ok, types} -> {:ok, {:oneof, Enum.reverse(types)}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp map_union_type(%{"refs" => refs}), do: {:error, {:unresolved_union, refs}}
  defp map_union_type(_), do: {:error, :invalid_union_definition}

  defp map_properties(properties, required) do
    Enum.reduce_while(properties, {:ok, %{}}, fn {key, type_def}, {:ok, acc} ->
      key_atom = String.to_atom(key)
      is_required = key in required

      case map_type(type_def) do
        {:ok, peri_type} ->
          final_type = wrap_if_required(peri_type, is_required)
          {:cont, {:ok, Map.put(acc, key_atom, final_type)}}

        {:error, reason} ->
          {:halt, {:error, {:property_mapping_failed, key, reason}}}
      end
    end)
  end

  defp wrap_if_required(peri_type, true), do: {:required, peri_type}
  defp wrap_if_required(peri_type, false), do: peri_type
end
