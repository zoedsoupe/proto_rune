defmodule ProtoRune.Lexicon.TypeMapper do
  @moduledoc """
  Maps ATProto lexicon types to Peri schema types.

  This module handles the conversion of AT Protocol type definitions
  (from lexicon JSON files) to Peri schema definitions that can be
  used for validation.

  ## Supported ATProto Types

  - Primitives: string, integer, boolean, bytes
  - Complex: object, array, ref, union
  - Special: unknown (maps to :any)
  - Formats: datetime, uri, did, handle, etc.

  ## Examples

      iex> TypeMapper.map_type(%{"type" => "string"})
      {:ok, :string}

      iex> TypeMapper.map_type(%{"type" => "integer"})
      {:ok, :integer}

      iex> TypeMapper.map_type(%{"type" => "array", "items" => %{"type" => "string"}})
      {:ok, {:list, :string}}

      iex> TypeMapper.map_type(%{"type" => "ref", "ref" => "com.atproto.repo.strongRef"})
      {:ok, {:ref, "com.atproto.repo.strongRef"}}
  """

  @type atproto_type :: map()
  @type peri_type :: atom() | tuple()
  @type mapping_result :: {:ok, peri_type()} | {:error, term()}

  @doc """
  Maps an ATProto type definition to a Peri schema type.

  ## Parameters

  - `type_def`: A map containing the ATProto type definition

  ## Returns

  - `{:ok, peri_type}` on success
  - `{:error, reason}` if mapping fails
  """
  @spec map_type(atproto_type()) :: mapping_result()
  def map_type(type_def) when is_map(type_def) do
    case type_def do
      %{"type" => "string"} = def ->
        map_string_type(def)

      %{"type" => "integer"} = def ->
        map_integer_type(def)

      %{"type" => "boolean"} ->
        {:ok, :boolean}

      %{"type" => "float"} = def ->
        map_float_type(def)

      %{"type" => "bytes"} ->
        {:ok, :string}

      %{"type" => "array", "items" => items} ->
        with {:ok, item_type} <- map_type(items) do
          {:ok, {:list, item_type}}
        end

      %{"type" => "object", "properties" => _props} ->
        map_object_type(type_def)

      %{"type" => "ref", "ref" => ref} ->
        {:ok, {:ref, ref}}

      %{"type" => "union", "refs" => refs} ->
        map_union_type(refs)

      %{"type" => "unknown"} ->
        {:ok, :any}

      %{"type" => "blob"} ->
        {:ok, :map}

      _ ->
        {:error, {:unsupported_type, type_def}}
    end
  end

  def map_type(_), do: {:error, :invalid_type_definition}

  @doc """
  Maps an object's properties to a Peri schema map.
  """
  @spec map_object_type(atproto_type()) :: mapping_result()
  def map_object_type(%{"properties" => properties, "required" => required})
      when is_map(properties) and is_list(required) do
    with {:ok, schema_map} <- map_properties(properties, required) do
      {:ok, schema_map}
    end
  end

  def map_object_type(%{"properties" => properties}) when is_map(properties) do
    map_properties(properties, [])
  end

  def map_object_type(_), do: {:error, :invalid_object_definition}

  # Private functions

  defp map_string_type(%{"format" => "datetime"}), do: {:ok, :datetime}
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

  defp map_union_type(refs) when is_list(refs) do
    ref_types = Enum.map(refs, &{:ref, &1})
    {:ok, {:oneof, ref_types}}
  end

  defp map_properties(properties, required) do
    result =
      Enum.reduce_while(properties, {:ok, %{}}, fn {key, type_def}, {:ok, acc} ->
        key_atom = String.to_atom(key)
        is_required = key in required

        case map_type(type_def) do
          {:ok, peri_type} ->
            final_type = if is_required, do: {:required, peri_type}, else: peri_type
            {:cont, {:ok, Map.put(acc, key_atom, final_type)}}

          {:error, reason} ->
            {:halt, {:error, {:property_mapping_failed, key, reason}}}
        end
      end)

    result
  end

  @doc """
  Extracts default value from an ATProto type definition if present.
  """
  @spec extract_default(atproto_type()) :: {:ok, term()} | :no_default
  def extract_default(%{"default" => value}), do: {:ok, value}
  def extract_default(_), do: :no_default

  @doc """
  Checks if a field is nullable in the ATProto definition.
  """
  @spec nullable?(atproto_type()) :: boolean()
  def nullable?(%{"nullable" => true}), do: true
  def nullable?(_), do: false

  @doc """
  Maps a lexicon record to a complete Peri schema including all definitions.
  """
  @spec map_record(map()) :: mapping_result()
  def map_record(%{"record" => record_def, "key" => _key} = def) do
    with {:ok, schema} <- map_type(record_def) do
      # Add metadata about the record
      {:ok,
       %{
         type: :record,
         schema: schema,
         description: def["description"]
       }}
    end
  end

  def map_record(%{"record" => record_def} = def) do
    with {:ok, schema} <- map_type(record_def) do
      {:ok,
       %{
         type: :record,
         schema: schema,
         description: def["description"]
       }}
    end
  end

  def map_record(_), do: {:error, :invalid_record_definition}
end
