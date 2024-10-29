defmodule Mix.Tasks.GenSchemas do
  @moduledoc """
  Mix task to generate Elixir modules from Lexicon schema definitions.
  """

  use Mix.Task

  @shortdoc "Generates Elixir modules from lexicon schema files"

  alias __MODULE__.{
    Context,
    Loader,
    DependencyResolver,
    Generator,
    TypeMapper,
    Utils
  }

  defmodule Context do
    @moduledoc false
    defstruct lexicons: [],
              defs_map: %{},
              generated_modules: MapSet.new(),
              output_dir: "lib/proto_rune"
  end

  @impl Mix.Task
  def run(args) do
    {opts, _remaining_args} = parse_args(args)

    case opts[:path] do
      nil ->
        Mix.raise("""
        Usage: mix gen_schemas --path priv/lexicons/

        You must provide a path to the lexicon files.
        """)

      path ->
        path
        |> expand_lexicon_files()
        |> generate_schemas(opts)
    end
  end

  defp parse_args(args) do
    OptionParser.parse!(args, strict: [path: :string, output_dir: :string])
  end

  defp expand_lexicon_files(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**/*.json"))
    else
      Mix.raise("Invalid path: #{path}")
    end
  end

  defp generate_schemas(files, opts) do
    with {:ok, lexicons} <- Loader.load_lexicons(files),
         {:ok, defs_map} <- Loader.build_defs_map(lexicons),
         {:ok, sorted_defs} <- DependencyResolver.sort_definitions(defs_map) do
      output_dir = opts[:output_dir] || "lib/proto_rune"

      context = %Context{
        lexicons: lexicons,
        defs_map: defs_map,
        generated_modules: MapSet.new(),
        output_dir: output_dir
      }

      Enum.each(sorted_defs, fn {lexicon_id, name} ->
        definition = Map.get(defs_map, {lexicon_id, name})

        if definition do
          Generator.generate_schema_module(%{
            context: context,
            lexicon_id: lexicon_id,
            name: name,
            definition: definition
          })
        else
          Mix.shell().error("Definition not found for #{lexicon_id}##{name}")
        end
      end)

      Mix.shell().info("Schema modules generated successfully!")
    else
      {:error, reason} ->
        Mix.raise("Failed to generate schemas: #{reason}")
    end
  end

  # -------------------------------
  # Loader Module
  # -------------------------------

  defmodule Loader do
    @moduledoc false

    alias Mix.Tasks.GenSchemas.Utils

    @doc """
    Loads lexicon JSON files and parses them into maps.
    """
    def load_lexicons(files) do
      files
      |> Enum.map(&load_lexicon/1)
      |> handle_lexicon_loading()
    end

    defp load_lexicon(file) do
      with {:ok, content} <- File.read(file),
           {:ok, lexicon} <- Utils.decode_json(content) do
        {:ok, Map.put(lexicon, "file_path", file)}
      else
        {:error, reason} -> {:error, "Failed to load #{file}: #{inspect(reason)}"}
      end
    end

    defp handle_lexicon_loading(lexicons) do
      Enum.reduce_while(lexicons, {:ok, []}, fn
        {:ok, lexicon}, {:ok, acc} -> {:cont, {:ok, [lexicon | acc]}}
        {:error, reason}, _ -> {:halt, {:error, reason}}
      end)
    end

    @doc """
    Builds a map of definitions from all loaded lexicons.
    """
    def build_defs_map(lexicons) do
      defs_map =
        Enum.reduce(lexicons, %{}, fn lexicon, acc ->
          lexicon_id = lexicon["id"]

          definitions = collect_all_definitions(lexicon)

          Enum.reduce(definitions, acc, fn {name, definition}, acc_inner ->
            Map.put(acc_inner, {lexicon_id, name}, definition)
          end)
        end)

      {:ok, defs_map}
    end

    defp collect_all_definitions(lexicon) do
      definitions = %{}

      definitions =
        if Map.has_key?(lexicon, "defs") do
          lexicon["defs"]
          |> Enum.reduce(definitions, fn {name, defn}, acc ->
            Map.merge(acc, collect_definition(defn, name))
          end)
        else
          definitions
        end

      # Include top-level definition if it has a "type"
      definitions =
        if Map.has_key?(lexicon, "type") do
          Map.merge(definitions, collect_definition(lexicon, "main"))
        else
          definitions
        end

      definitions
    end

    defp collect_definition(definition, name) do
      definitions = %{name => definition}

      definitions =
        Enum.reduce(definition, definitions, fn
          {_key, %{"type" => _} = value}, acc ->
            nested_name = Map.get(value, "name", name)
            nested_defs = collect_definition(value, nested_name)
            Map.merge(acc, nested_defs)

          {_key, %{"defs" => defs}}, acc ->
            nested_defs =
              defs
              |> Enum.reduce(%{}, fn {def_name, def_value}, nested_acc ->
                collect_definition(def_value, def_name)
                |> Map.merge(nested_acc)
              end)

            Map.merge(acc, nested_defs)

          {_key, _value}, acc ->
            acc
        end)

      definitions
    end
  end

  # -------------------------------
  # DependencyResolver Module
  # -------------------------------

  defmodule DependencyResolver do
    @moduledoc false

    alias Mix.Tasks.GenSchemas.Utils

    @doc """
    Sorts definitions based on their dependencies.
    """
    def sort_definitions(defs_map) do
      graph = :digraph.new()

      try do
        Enum.each(defs_map, fn {{lexicon_id, name}, definition} ->
          vertex = {lexicon_id, name}
          :digraph.add_vertex(graph, vertex)

          refs = Utils.collect_references(lexicon_id, definition)

          Enum.each(refs, fn {ref_id, ref_name} ->
            :digraph.add_vertex(graph, {ref_id, ref_name})
            :digraph.add_edge(graph, {ref_id, ref_name}, vertex)
          end)
        end)

        sorted_vertices = :digraph_utils.topsort(graph)

        if sorted_vertices == false do
          Mix.shell().info("Circular dependency detected. Proceeding with arbitrary order.")
          vertices = :digraph.vertices(graph)
          {:ok, vertices}
        else
          {:ok, sorted_vertices}
        end
      after
        :digraph.delete(graph)
      end
    end
  end

  # -------------------------------
  # Generator Module
  # -------------------------------

  defmodule Generator do
    @moduledoc false

    alias Mix.Tasks.GenSchemas.{TypeMapper, Utils, Context}

    @doc """
    Generates Elixir modules based on the schema definitions.
    """
    def generate_schema_module(%{
          context: context,
          lexicon_id: lexicon_id,
          name: name,
          definition: definition
        }) do
      type = definition["type"]

      module_name = Utils.module_name(lexicon_id, name)

      unless MapSet.member?(context.generated_modules, module_name) do
        context = %Context{
          context
          | generated_modules: MapSet.put(context.generated_modules, module_name)
        }

        case type do
          "object" ->
            generate_object_module(%{
              context: context,
              lexicon_id: lexicon_id,
              name: name,
              definition: definition
            })

          "record" ->
            record_definition = Map.put(definition["record"], "name", name)

            generate_schema_module(%{
              context: context,
              lexicon_id: lexicon_id,
              name: name,
              definition: record_definition
            })

          "token" ->
            generate_token_module(module_name, name, definition, context.output_dir)

          "query" ->
            generate_query_module(%{
              context: context,
              lexicon_id: lexicon_id,
              name: name,
              definition: definition
            })

          "procedure" ->
            generate_procedure_module(%{
              context: context,
              lexicon_id: lexicon_id,
              name: name,
              definition: definition
            })

          _ ->
            typespec =
              TypeMapper.type_to_elixir(%{
                context: context,
                lexicon_id: lexicon_id,
                definition: definition
              })

            module_contents = Utils.render_type_module(module_name, name, definition, typespec)
            Utils.write_module_file(module_name, module_contents, context.output_dir)
        end
      end
    end

    def generate_query_module(%{
          context: context,
          lexicon_id: lexicon_id,
          name: name,
          definition: definition
        }) do
      module_name = Utils.module_name(lexicon_id, name)
      description = Map.get(definition || %{}, "description", "No description provided.")

      # Process parameters or input
      input_typespec =
        cond do
          Map.has_key?(definition, "parameters") ->
            TypeMapper.type_to_elixir(%{
              context: context,
              lexicon_id: lexicon_id,
              definition: Utils.extract_schema(definition["parameters"])
            })

          Map.has_key?(definition, "input") ->
            TypeMapper.type_to_elixir(%{
              context: context,
              lexicon_id: lexicon_id,
              definition: Utils.extract_schema(definition["input"])
            })

          true ->
            nil
        end

      # Process output
      output_typespec =
        if Map.has_key?(definition, "output") do
          TypeMapper.type_to_elixir(%{
            context: context,
            lexicon_id: lexicon_id,
            definition: Utils.extract_schema(definition["output"])
          })
        else
          nil
        end

      # Process errors
      error_types =
        if Map.has_key?(definition, "errors") do
          Enum.map(definition["errors"], fn error_def ->
            error_name = error_def["name"]

            # Generate a module for the error
            error_module_name = Utils.module_name(lexicon_id, "#{name}Error#{error_name}")

            error_definition =
              Map.put(error_def["schema"] || %{}, "name", "#{name}Error#{error_name}")

            generate_schema_module(%{
              context: context,
              lexicon_id: lexicon_id,
              name: "#{name}Error#{error_name}",
              definition: error_definition
            })

            "#{inspect(error_module_name)}.t()"
          end)
        else
          []
        end

      typespecs = []

      typespecs =
        if input_typespec do
          [{"input", input_typespec} | typespecs]
        else
          typespecs
        end

      typespecs =
        if output_typespec do
          [{"output", output_typespec} | typespecs]
        else
          typespecs
        end

      typespecs_content = Utils.render_typespecs(typespecs)

      # If there are errors, define a @type error
      error_typespec = Utils.render_error_typespec(error_types)

      module_contents = """
      # This module was generated by Mix.Tasks.GenSchemas
      defmodule #{inspect(module_name)} do
        @moduledoc \"\"\"
        Generated query module for #{name}

        **Description**: #{description}
        \"\"\"

        #{typespecs_content}
        #{error_typespec}
      end
      """

      Utils.write_module_file(module_name, module_contents, context.output_dir)
    end

    def generate_procedure_module(%{
          context: context,
          lexicon_id: lexicon_id,
          name: name,
          definition: definition
        }) do
      module_name = Utils.module_name(lexicon_id, name)
      description = Map.get(definition || %{}, "description", "No description provided.")

      # Process input
      input_typespec =
        if Map.has_key?(definition, "input") do
          TypeMapper.type_to_elixir(%{
            context: context,
            lexicon_id: lexicon_id,
            definition: Utils.extract_schema(definition["input"])
          })
        else
          nil
        end

      # Process output
      output_typespec =
        if Map.has_key?(definition, "output") do
          TypeMapper.type_to_elixir(%{
            context: context,
            lexicon_id: lexicon_id,
            definition: Utils.extract_schema(definition["output"])
          })
        else
          nil
        end

      # Process errors
      error_types =
        if Map.has_key?(definition, "errors") do
          Enum.map(definition["errors"], fn error_def ->
            error_name = error_def["name"]

            # Generate a module for the error
            error_module_name = Utils.module_name(lexicon_id, "#{name}Error#{error_name}")

            error_definition =
              Map.put(error_def["schema"] || %{}, "name", "#{name}Error#{error_name}")

            generate_schema_module(%{
              context: context,
              lexicon_id: lexicon_id,
              name: "#{name}Error#{error_name}",
              definition: error_definition
            })

            "#{inspect(error_module_name)}.t()"
          end)
        else
          []
        end

      typespecs = []

      typespecs =
        if input_typespec do
          [{"input", input_typespec} | typespecs]
        else
          typespecs
        end

      typespecs =
        if output_typespec do
          [{"output", output_typespec} | typespecs]
        else
          typespecs
        end

      typespecs_content = Utils.render_typespecs(typespecs)

      # If there are errors, define a @type error
      error_typespec = Utils.render_error_typespec(error_types)

      module_contents = """
      # This module was generated by Mix.Tasks.GenSchemas
      defmodule #{inspect(module_name)} do
        @moduledoc \"\"\"
        Generated procedure module for #{name}

        **Description**: #{description}
        \"\"\"

        #{typespecs_content}
        #{error_typespec}
      end
      """

      Utils.write_module_file(module_name, module_contents, context.output_dir)
    end

    def generate_object_module(%{
          context: context,
          lexicon_id: lexicon_id,
          name: name,
          definition: definition
        }) do
      module_name = Utils.module_name(lexicon_id, name)
      properties = Map.get(definition, "properties", %{})
      required_fields = Utils.get_required_fields(definition)
      nullable_fields = Utils.get_nullable_fields(definition)
      fields = Utils.get_fields(properties)

      typespecs =
        Enum.map(properties, fn {field_name, prop_def} ->
          field_atom = Utils.field_name_to_atom(field_name)

          field_typespec =
            TypeMapper.type_to_elixir(%{
              context: context,
              lexicon_id: lexicon_id,
              definition: prop_def
            })

          field_typespec =
            if field_atom in nullable_fields do
              "#{field_typespec} | nil"
            else
              field_typespec
            end

          {field_atom, field_typespec}
        end)

      module_contents =
        Utils.render_object_module(
          module_name,
          name,
          definition,
          fields,
          required_fields,
          typespecs
        )

      Utils.write_module_file(module_name, module_contents, context.output_dir)
    end

    def generate_token_module(module_name, name, definition, output_dir) do
      module_contents = Utils.render_token_module(module_name, name, definition)
      Utils.write_module_file(module_name, module_contents, output_dir)
    end
  end

  # -------------------------------
  # TypeMapper Module
  # -------------------------------

  defmodule TypeMapper do
    @moduledoc false

    alias Mix.Tasks.GenSchemas.{Utils, Generator}

    @doc """
    Maps lexicon types to Elixir typespecs.
    """
    def type_to_elixir(%{
          context: context,
          lexicon_id: lexicon_id,
          definition: definition
        }) do
      type = definition["type"]

      cond do
        type == "null" -> "nil"
        type == "boolean" -> "boolean()"
        type == "integer" -> "integer()"
        type == "float" -> "float()"
        type == "string" -> string_type(definition)
        type == "bytes" -> "binary()"
        type == "cid-link" -> "binary()"
        type == "blob" -> "binary()"
        type == "array" -> array_type(context, lexicon_id, definition)
        type in ["object", "params"] -> object_type(context, lexicon_id, definition)
        type == "token" -> "atom()"
        type == "ref" -> ref_type(context, lexicon_id, definition)
        type == "union" -> union_type(context, lexicon_id, definition)
        type == "unknown" -> "any()"
        true -> "any()"
      end
    end

    defp string_type(definition) do
      cond do
        definition["const"] ->
          Utils.atom_literal(definition["const"])

        definition["knownValues"] ->
          Enum.map_join(definition["knownValues"], " | ", &Utils.atom_literal/1)

        definition["enum"] ->
          Enum.map_join(definition["enum"], " | ", &Utils.atom_literal/1)

        true ->
          "String.t()"
      end
    end

    defp array_type(context, lexicon_id, definition) do
      items = definition["items"]

      item_type =
        type_to_elixir(%{
          context: context,
          lexicon_id: lexicon_id,
          definition: items
        })

      "list(#{item_type})"
    end

    defp object_type(context, lexicon_id, definition) do
      case Map.get(definition, "name") do
        nil ->
          inline_object_type(context, lexicon_id, definition)

        name ->
          module_name = Utils.module_name(lexicon_id, name)

          Generator.generate_object_module(%{
            context: context,
            lexicon_id: lexicon_id,
            name: name,
            definition: definition
          })

          "#{inspect(module_name)}.t()"
      end
    end

    defp inline_object_type(context, lexicon_id, definition) do
      properties = Map.get(definition, "properties", %{})
      nullable_fields = Map.get(definition, "nullable", [])

      typespecs =
        Enum.map(properties, fn {field_name, prop_def} ->
          field_atom = Utils.field_name_to_atom(field_name)

          field_typespec =
            type_to_elixir(%{
              context: context,
              lexicon_id: lexicon_id,
              definition: prop_def
            })

          field_typespec =
            if field_name in nullable_fields do
              "#{field_typespec} | nil"
            else
              field_typespec
            end

          "#{field_atom}: #{field_typespec}"
        end)

      "%{#{Enum.join(typespecs, ", ")}}"
    end

    defp ref_type(context, lexicon_id, definition) do
      ref = definition["ref"]
      {ref_id, ref_name} = Utils.parse_ref(lexicon_id, ref)

      ref_definition =
        get_definition(context, ref_id, ref_name)

      if ref_definition do
        Generator.generate_schema_module(%{
          context: context,
          lexicon_id: ref_id,
          name: ref_name,
          definition: ref_definition
        })

        module_name = Utils.module_name(ref_id, ref_name)
        "#{inspect(module_name)}.t()"
      else
        raise "Cannot resolve reference to #{ref_id}##{ref_name}"
      end
    end

    defp union_type(context, lexicon_id, definition) do
      refs = definition["refs"] || []

      types =
        Enum.map(refs, fn ref ->
          {ref_id, ref_name} = Utils.parse_ref(lexicon_id, ref)

          ref_definition =
            get_definition(context, ref_id, ref_name)

          if ref_definition do
            Generator.generate_schema_module(%{
              context: context,
              lexicon_id: ref_id,
              name: ref_name,
              definition: ref_definition
            })

            module_name = Utils.module_name(ref_id, ref_name)
            "#{inspect(module_name)}.t()"
          else
            raise "Cannot resolve reference to #{ref_id}##{ref_name}"
          end
        end)

      Enum.join(types, " | ")
    end

    defp get_definition(context, ref_id, name) do
      Map.get(context.defs_map, {ref_id, name})
    end
  end

  # -------------------------------
  # Utils Module
  # -------------------------------

  defmodule Utils do
    @moduledoc false

    @doc """
    Decodes JSON content and handles errors.
    """
    def decode_json(content) do
      case Jason.decode(content) do
        {:ok, data} -> {:ok, data}
        error -> error
      end
    end

    @doc """
    Parses a reference string into lexicon ID and name.
    """
    def parse_ref(current_id, ref) do
      cond do
        String.starts_with?(ref, "#") ->
          {current_id, String.trim_leading(ref, "#")}

        String.contains?(ref, "#") ->
          [nsid, local_name] = String.split(ref, "#")
          {nsid, local_name}

        true ->
          {ref, "main"}
      end
    end

    @doc """
    Collects all references from a definition for dependency resolution.
    """
    def collect_references(lexicon_id, definition) do
      do_collect_refs(lexicon_id, definition, [])
      |> Enum.uniq()
    end

    defp do_collect_refs(current_id, %{"type" => "ref", "ref" => ref}, acc) do
      {ref_id, ref_name} = parse_ref(current_id, ref)
      [{ref_id, ref_name} | acc]
    end

    defp do_collect_refs(current_id, %{"type" => "union", "refs" => refs}, acc) do
      Enum.reduce(refs, acc, fn ref, acc_inner ->
        {ref_id, ref_name} = parse_ref(current_id, ref)
        [{ref_id, ref_name} | acc_inner]
      end)
    end

    defp do_collect_refs(current_id, %{"properties" => properties}, acc) do
      Enum.reduce(properties, acc, fn {_key, value}, acc_inner ->
        do_collect_refs(current_id, value, acc_inner)
      end)
    end

    defp do_collect_refs(current_id, %{"items" => items}, acc) do
      do_collect_refs(current_id, items, acc)
    end

    defp do_collect_refs(current_id, %{"parameters" => parameters}, acc) do
      Enum.reduce(parameters, acc, fn {_key, value}, acc_inner ->
        do_collect_refs(current_id, value, acc_inner)
      end)
    end

    defp do_collect_refs(current_id, %{"input" => input}, acc) do
      do_collect_refs(current_id, input, acc)
    end

    defp do_collect_refs(current_id, %{"output" => output}, acc) do
      do_collect_refs(current_id, output, acc)
    end

    defp do_collect_refs(current_id, %{"schema" => schema}, acc) do
      do_collect_refs(current_id, schema, acc)
    end

    defp do_collect_refs(current_id, %{"errors" => errors}, acc) do
      Enum.reduce(errors, acc, fn error_def, acc_inner ->
        if Map.has_key?(error_def, "schema") do
          do_collect_refs(current_id, error_def["schema"], acc_inner)
        else
          acc_inner
        end
      end)
    end

    defp do_collect_refs(_current_id, _other, acc), do: acc

    @doc """
    Extracts the schema from a definition if present.
    """
    def extract_schema(definition) when is_map(definition) do
      if Map.has_key?(definition, "schema") do
        Map.get(definition, "schema")
      else
        definition
      end
    end

    @doc """
    Converts a field name to an atom, handling snake_case conversion.
    """
    def field_name_to_atom(field_name) do
      field_name |> Macro.underscore() |> String.to_atom()
    end

    @doc """
    Generates the module name from lexicon ID and definition name.
    """
    def module_name(lexicon_id, name) do
      module_parts =
        ["ProtoRune" | lexicon_id_to_module_parts(lexicon_id)] ++
          name_to_module_parts(name)

      Module.concat(module_parts)
    end

    defp lexicon_id_to_module_parts(lexicon_id) do
      lexicon_id
      |> String.split(".")
      |> Enum.map(&Macro.camelize/1)
    end

    defp name_to_module_parts("main"), do: []

    defp name_to_module_parts(name) do
      name
      |> String.split("#")
      |> Enum.map(&Macro.camelize/1)
    end

    @doc """
    Writes the generated module contents to a file, using the provided output directory.
    """
    def write_module_file(module_name, module_contents, output_dir) do
      file_path =
        module_name
        |> Module.split()
        |> tl()
        |> Enum.map(&Macro.underscore/1)
        |> Path.join()
        |> (&Path.join(output_dir, "#{&1}.ex")).()

      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, module_contents)
    end

    @doc """
    Renders a type module.
    """
    def render_type_module(module_name, name, definition, typespec) do
      description = Map.get(definition || %{}, "description", "No description provided.")

      """
      # This module was generated by Mix.Tasks.GenSchemas
      defmodule #{inspect(module_name)} do
        @moduledoc \"\"\"
        Generated schema for #{name}

        **Description**: #{description}
        \"\"\"

        @type t :: #{typespec}
      end
      """
    end

    @doc """
    Renders an object module.
    """
    def render_object_module(module_name, name, definition, fields, required_fields, typespecs) do
      description = Map.get(definition || %{}, "description", "No description provided.")

      enforce_keys =
        if required_fields != [], do: "@enforce_keys #{inspect(required_fields)}", else: ""

      # Use keyword list for defstruct
      struct_fields = fields |> Enum.map(&{&1, nil})

      typespecs_lines =
        Enum.map_join(typespecs, ",\n", fn {field_atom, typespec} ->
          "    #{field_atom}: #{typespec}"
        end)

      """
      # This module was generated by Mix.Tasks.GenSchemas
      defmodule #{inspect(module_name)} do
        @moduledoc \"\"\"
        Generated schema for #{name}

        **Description**: #{description}
        \"\"\"

        #{enforce_keys}
        defstruct #{inspect(struct_fields)}

        @type t :: %__MODULE__{
        #{typespecs_lines}
        }
      end
      """
    end

    @doc """
    Renders a token module.
    """
    def render_token_module(module_name, name, definition) do
      description = Map.get(definition || %{}, "description", "No description provided.")

      """
      # This module was generated by Mix.Tasks.GenSchemas
      defmodule #{inspect(module_name)} do
        @moduledoc \"\"\"
        Token type for #{name}

        **Description**: #{description}
        \"\"\"

        @type t :: atom()
      end
      """
    end

    @doc """
    Renders typespecs for input and output.
    """
    def render_typespecs(typespecs) do
      Enum.map_join(typespecs, "\n", fn {name, typespec} ->
        "@type #{name} :: #{typespec}"
      end)
    end

    @doc """
    Renders the error typespec.
    """
    def render_error_typespec(error_types) do
      case error_types do
        [] -> ""
        _ -> "@type error :: #{Enum.join(error_types, " | ")}"
      end
    end

    @valid_atom ~r/^[A-Za-z_][A-Za-z0-9_]*[!?]?$/

    @doc """
    Converts a value to an atom literal for typespecs.
    """
    def atom_literal(value) do
      if value =~ @valid_atom do
        ":#{String.replace(value, "\"", "\\\"")}"
      else
        ":\"#{String.replace(value, "\"", "\\\"")}\""
      end
    end

    @doc """
    Retrieves required fields from a definition.
    """
    def get_required_fields(definition) do
      Map.get(definition, "required", [])
      |> Enum.map(&field_name_to_atom/1)
    end

    @doc """
    Retrieves nullable fields from a definition.
    """
    def get_nullable_fields(definition) do
      Map.get(definition, "nullable", [])
      |> Enum.map(&field_name_to_atom/1)
    end

    @doc """
    Retrieves all fields from properties.
    """
    def get_fields(properties) do
      Map.keys(properties)
      |> Enum.map(&field_name_to_atom/1)
    end
  end
end
