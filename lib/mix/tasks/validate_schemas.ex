defmodule Mix.Tasks.ValidateSchemas do
  @moduledoc """
  Strictly validates that the generated Elixir typespecs match the Lexicon
  definitions **exactly**, using remote type references to avoid recursion.

  ## Usage

      mix validate_schemas --path priv/lexicons

  Steps:

  1. Load each Lexicon JSON file.
  2. Build a map of definitions: `{ {lex_id, def_name} => definition }`.
  3. For each definition (object, record, query, procedure, basic):
     - Logs that we're validating it.
     - Builds the *expected* Elixir type AST from the Lexicon, returning references for named schemas.
     - Locates the *actual* compiled typespec in the relevant module or `ProtoRune.Lexicons`.
     - Compares them and logs success or mismatches.
  4. Raises an error if any mismatch occurs, otherwise logs overall success.
  """

  use Mix.Task

  @shortdoc "Strictly validates generated typespecs, with logs and reference-based expansions."

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining} = parse_args(args)
    path = opts[:path] || raise_missing_path!()

    Mix.shell().info("[validate_schemas] Loading lexicons from: #{path}")
    files = expand_lexicon_files(path)
    lexicons = load_lexicons!(files)
    defs_map = build_defs_map(lexicons)
    Mix.shell().info("[validate_schemas] Loaded #{map_size(defs_map)} definitions.")

    # Validate each definition; accumulate errors in a single list
    errors =
      Enum.flat_map(defs_map, fn {{lex_id, def_name}, definition} ->
        Mix.shell().info("Validating definition: #{lex_id}##{def_name} ...")
        validate_definition(lex_id, def_name, definition, defs_map)
      end)

    if errors == [] do
      Mix.shell().info("[validate_schemas] All definitions match EXACT typespecs. Success!")
    else
      Mix.shell().error("[validate_schemas] Found mismatches:")
      Enum.each(errors, &Mix.shell().error("  - #{&1}"))
      Mix.raise("Validation failed with #{length(errors)} error(s).")
    end
  end

  # ------------------------------------------------------------------
  # Parsing & loading
  # ------------------------------------------------------------------
  defp parse_args(args) do
    OptionParser.parse!(args, strict: [path: :string])
  end

  defp raise_missing_path! do
    Mix.raise("""
    Missing --path argument. Usage:
        mix validate_schemas --path priv/lexicons/
    """)
  end

  defp expand_lexicon_files(path) do
    unless File.dir?(path), do: Mix.raise("Invalid path: #{path}")
    Path.wildcard(Path.join(path, "**/*.json"))
  end

  defp load_lexicons!(files) do
    Enum.map(files, fn file ->
      case File.read(file) do
        {:ok, contents} ->
          case Jason.decode(contents) do
            {:ok, json} -> Map.put(json, "file_path", file)
            error -> Mix.raise("JSON decode error for #{file}: #{inspect(error)}")
          end

        {:error, reason} ->
          Mix.raise("Cannot read #{file}: #{inspect(reason)}")
      end
    end)
  end

  # ------------------------------------------------------------------
  # Building a definitions map
  # ------------------------------------------------------------------
  defp build_defs_map(lexicons) do
    Enum.reduce(lexicons, %{}, fn lexicon, acc ->
      lex_id = lexicon["id"] || "unknown.lexicon"
      defs = gather_definitions(lexicon)

      Enum.reduce(defs, acc, fn {def_name, def_val}, acc_inner ->
        Map.put(acc_inner, {lex_id, def_name}, def_val)
      end)
    end)
  end

  defp gather_definitions(lexicon) do
    top_level =
      if lexicon["type"], do: %{"main" => lexicon}, else: %{}

    Map.merge(top_level, lexicon["defs"] || %{})
  end

  # ------------------------------------------------------------------
  # Main validation entry
  # ------------------------------------------------------------------
  defp validate_definition(lex_id, def_name, definition, defs_map) do
    case definition["type"] do
      t when t in ["object", "record"] ->
        validate_complex_type(lex_id, def_name, definition, defs_map)

      t when t in ["query", "procedure"] ->
        validate_query_or_proc(lex_id, def_name, definition, defs_map)

      _other ->
        validate_basic_type(lex_id, def_name, definition, defs_map)
    end
  end

  # ------------------------------------------------------------------
  # Validate an object/record => expect a module with `@type t :: ...`
  # ------------------------------------------------------------------
  defp validate_complex_type(lex_id, def_name, definition, defs_map) do
    mod = build_module_name(lex_id, def_name)

    case ensure_module_loaded(mod) do
      :error ->
        ["Missing module #{inspect(mod)} for object/record #{lex_id}##{def_name}."]

      :ok ->
        expected_ast = build_struct_ast(lex_id, def_name, definition, defs_map)

        case check_typespec_mismatch(mod, :t, expected_ast) do
          nil ->
            Mix.shell().info("  ✓ Matches @type t in #{inspect(mod)}")
            []

          {:mismatch, msg} ->
            [msg]
        end
    end
  end

  # ------------------------------------------------------------------
  # Validate a query/procedure => expect a module with `@type input` and/or `@type output`
  # ------------------------------------------------------------------
  defp validate_query_or_proc(lex_id, def_name, definition, defs_map) do
    mod = build_module_name(lex_id, def_name)

    case ensure_module_loaded(mod) do
      :error ->
        ["Missing module #{inspect(mod)} for query/procedure #{lex_id}##{def_name}."]

      :ok ->
        errors = []

        # If we have an input
        if is_map(definition["input"]) do
          expected_in = build_type_ast(lex_id, definition["input"], defs_map)

          case check_typespec_mismatch(mod, :input, expected_in) do
            nil ->
              Mix.shell().info("  ✓ Matches @type input in #{inspect(mod)}")

            {:mismatch, msg} ->
              errors = errors ++ [msg]
          end
        end

        # If we have an output
        if is_map(definition["output"]) do
          expected_out = build_type_ast(lex_id, definition["output"], defs_map)

          case check_typespec_mismatch(mod, :output, expected_out) do
            nil ->
              Mix.shell().info("  ✓ Matches @type output in #{inspect(mod)}")

            {:mismatch, msg} ->
              errors = errors ++ [msg]
          end
        end

        errors
    end
  end

  # ------------------------------------------------------------------
  # Validate a basic (non-struct) definition => expect @type in `ProtoRune.Lexicons`
  # ------------------------------------------------------------------
  defp validate_basic_type(lex_id, def_name, definition, defs_map) do
    type_mod = ProtoRune.Lexicons
    type_atom = String.to_atom(raw_type_name(lex_id, def_name))

    case ensure_module_loaded(type_mod) do
      :error ->
        ["Missing `ProtoRune.Lexicons` module for basic type #{type_atom}."]

      :ok ->
        expected_ast = build_type_ast(lex_id, definition, defs_map)

        case check_typespec_mismatch(type_mod, type_atom, expected_ast) do
          nil ->
            Mix.shell().info("  ✓ Matches @type #{type_atom} in ProtoRune.Lexicons")
            []

          {:mismatch, msg} ->
            [msg]
        end
    end
  end

  # ------------------------------------------------------------------
  # Compare actual compiled AST to expected AST
  # ------------------------------------------------------------------
  defp check_typespec_mismatch(mod, type_name, expected_ast) do
    actual_ast = fetch_type_ast(mod, type_name)

    cond do
      actual_ast == nil ->
        {:mismatch, "Module #{inspect(mod)} missing @type #{type_name}."}

      same_ast?(expected_ast, actual_ast) ->
        nil

      true ->
        {:mismatch,
         """
         Mismatch in #{inspect(mod)}.@type #{type_name}:

         Expected: #{Macro.to_string(expected_ast)}
         Got:      #{Macro.to_string(actual_ast)}
         """}
    end
  end

  defp fetch_type_ast(mod, type_name) do
    case Code.Typespec.fetch_types(mod) do
      {:ok, all_types} ->
        Enum.find_value(all_types, fn
          {:type, {^type_name, _, quoted}} -> quoted
          {:opaque, {^type_name, _, quoted}} -> quoted
          _ -> nil
        end)

      :error ->
        nil
    end
  end

  # ------------------------------------------------------------------
  # Building an AST for an object/record => `%MyModule{field: ...}`
  # ------------------------------------------------------------------
  defp build_struct_ast(lex_id, def_name, definition, defs_map) do
    mod_ast = build_module_ast(lex_id, def_name)
    props = Map.get(definition, "properties", %{})
    nullable = Map.get(definition, "nullable", [])

    fields_ast =
      Enum.map(props, fn {k, v} ->
        field_ast = build_type_ast(lex_id, v, defs_map)
        {String.to_atom(k), maybe_union_nil(field_ast, k, nullable)}
      end)

    struct_map = {:%{}, [], fields_ast}
    {:%, [], [mod_ast, struct_map]}
  end

  defp maybe_union_nil(field_ast, k, nullable_list) do
    if k in nullable_list or String.to_atom(k) in nullable_list do
      union_ast([field_ast, nil_ast()])
    else
      field_ast
    end
  end

  # ------------------------------------------------------------------
  # Building an AST from a definition (inline expansions for anonymous objects,
  # remote type references for named or basic references).
  # ------------------------------------------------------------------
  defp build_type_ast(_lex_id, nil, _defs_map), do: builtin_ast(:any)

  defp build_type_ast(current_lex, %{"type" => "ref", "ref" => ref}, defs_map) do
    {r_lex, r_name} = parse_ref(current_lex, ref)
    ref_def = Map.get(defs_map, {r_lex, r_name})

    # If missing => fallback to any
    if ref_def == nil do
      Mix.shell().info("  [debug] Missing reference: #{r_lex}##{r_name}, fallback to any()")
      builtin_ast(:any)
    else
      case ref_def["type"] do
        "object" ->
          remote_type_ast(build_module_ast(r_lex, r_name), :t)

        "record" ->
          remote_type_ast(build_module_ast(r_lex, r_name), :t)

        "query" ->
          remote_type_ast(build_module_ast(r_lex, r_name), :output)

        "procedure" ->
          remote_type_ast(build_module_ast(r_lex, r_name), :output)

        _ ->
          # Basic => from ProtoRune.Lexicons
          type_atom = String.to_atom(raw_type_name(r_lex, r_name))
          remote_types_ast({:alias, build_module_ast("ProtoRune", "Lexicons")}, type_atom)
      end
    end
  end

  defp build_type_ast(current_lex, %{"type" => "union", "refs" => refs}, defs_map)
       when is_list(refs) do
    members =
      Enum.map(refs, fn r ->
        {rx, rn} = parse_ref(current_lex, r)
        sub_def = Map.get(defs_map, {rx, rn}, %{"type" => "unknown"})
        build_type_ast(rx, sub_def, defs_map)
      end)

    union_ast(members)
  end

  defp build_type_ast(current_lex, %{"type" => "object"} = defn, defs_map) do
    # If it has a "name", produce a remote type reference => MyModule.t()
    if is_binary(defn["name"]) do
      remote_type_ast(build_module_ast(current_lex, defn["name"]), :t)
    else
      # inline => build a map, no recursion for references
      props = Map.get(defn, "properties", %{})
      nullable = Map.get(defn, "nullable", [])

      fields =
        Enum.map(props, fn {k, v} ->
          ast = build_type_ast(current_lex, v, defs_map)
          {String.to_atom(k), maybe_union_nil(ast, k, nullable)}
        end)

      {:%{}, [], fields}
    end
  end

  defp build_type_ast(current_lex, %{"type" => "array", "items" => items}, defs_map) do
    item_ast = build_type_ast(current_lex, items, defs_map)
    {:type, 0, :list, [item_ast]}
  end

  # Basic scalars
  defp build_type_ast(_lex, %{"type" => "null"}, _defs_map), do: nil_ast()
  defp build_type_ast(_lex, %{"type" => "boolean"}, _), do: builtin_ast(:boolean)
  defp build_type_ast(_lex, %{"type" => "integer"}, _), do: builtin_ast(:integer)
  defp build_type_ast(_lex, %{"type" => "float"}, _), do: builtin_ast(:float)
  defp build_type_ast(_lex, %{"type" => "bytes"}, _), do: builtin_ast(:binary)
  defp build_type_ast(_lex, %{"type" => "cid-link"}, _), do: builtin_ast(:binary)
  defp build_type_ast(_lex, %{"type" => "blob"}, _), do: builtin_ast(:binary)
  defp build_type_ast(_lex, %{"type" => "token"}, _), do: builtin_ast(:atom)
  defp build_type_ast(_lex, %{"type" => "unknown"}, _), do: builtin_ast(:any)

  defp build_type_ast(_lex, %{"type" => "string"} = defn, _defs_map) do
    cond do
      defn["const"] ->
        literal_atom_ast(defn["const"])

      is_list(defn["knownValues"]) ->
        union_ast(Enum.map(defn["knownValues"], &literal_atom_ast/1))

      is_list(defn["enum"]) ->
        union_ast(Enum.map(defn["enum"], &literal_atom_ast/1))

      true ->
        builtin_ast(:string)
    end
  end

  # fallback
  defp build_type_ast(_lex, _stuff, _), do: builtin_ast(:any)

  # ------------------------------------------------------------------
  # AST Helpers
  # ------------------------------------------------------------------
  defp builtin_ast(name), do: {:type, 0, name, []}
  defp nil_ast, do: {:atom, 0, nil}

  defp literal_atom_ast(value),
    do: {:atom, 0, String.to_atom(value)}

  # union [x,y,z] => x | (y | z)
  defp union_ast([]), do: builtin_ast(:any)
  defp union_ast([one]), do: one
  defp union_ast([first, second]), do: {:|, [], [first, second]}
  defp union_ast([head | tail]), do: {:|, [], [head, union_ast(tail)]}

  # remote type in ProtoRune.Lexicons => e.g. `ProtoRune.Lexicons.my_type_alias()`
  defp remote_types_ast(module_ast, type_atom) do
    {:type, 0, :remote, [module_ast, {:atom, 0, :type}, [{:atom, 0, type_atom}]]}
  end

  # remote type in a struct module => e.g. `MyModule.t()`
  defp remote_type_ast(module_ast, type_atom) do
    alias_ast = {:alias, module_ast}
    remote_types_ast(alias_ast, type_atom)
  end

  defp raw_type_name(lex_id, def_name) do
    (lex_id <> "_" <> def_name)
    |> String.replace("#", "_")
    |> String.replace(".", "_")
    |> Macro.underscore()
  end

  defp build_module_name(lex_id, def_name) do
    base_parts = lex_id |> String.split(".") |> Enum.map(&Macro.camelize/1)
    local_parts = def_name |> String.split("#") |> Enum.map(&Macro.camelize/1)
    Module.concat([ProtoRune | base_parts ++ local_parts])
  end

  # Compare AST ignoring metadata
  defp same_ast?(left, right), do: strip_meta(left) == strip_meta(right)

  defp strip_meta({a, _m, b}) when is_list(b),
    do: {strip_meta(a), [], Enum.map(b, &strip_meta/1)}

  defp strip_meta(list) when is_list(list),
    do: Enum.map(list, &strip_meta/1)

  defp strip_meta(other),
    do: other

  # Ensure a module is loaded
  defp ensure_module_loaded(mod) do
    case Code.ensure_compiled(mod) do
      {:module, ^mod} -> :ok
      _ -> :error
    end
  end

  # parse_ref: "com.example.foo#bar" => { "com.example.foo", "bar" }
  # or "#bar" => { current_lex, "bar" }
  # or "com.example.foo" => { "com.example.foo", "main" }
  defp parse_ref(current_lex, ref) do
    cond do
      String.starts_with?(ref, "#") ->
        {current_lex, String.trim_leading(ref, "#")}

      String.contains?(ref, "#") ->
        [nsid, local] = String.split(ref, "#", parts: 2)
        {nsid, local}

      true ->
        {ref, "main"}
    end
  end
end
