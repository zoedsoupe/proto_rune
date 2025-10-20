defmodule ProtoRune.Lexicon.Generator do
  @moduledoc """
  Generates Elixir modules with Peri schemas from AT Protocol lexicon definitions.

  This module is responsible for:
  - Parsing lexicon JSON files
  - Converting lexicon types to Peri schema definitions using TypeMapper
  - Generating Elixir module source code
  - Writing generated modules to disk

  ## Example

      # Generate a module for app.bsky.feed.post
      {:ok, source} = Generator.generate_module(lexicon_map)
      File.write!("lib/proto_rune/lexicon/generated/app/bsky/feed/post.ex", source)
  """

  alias ProtoRune.Lexicon.TypeMapper

  @type lexicon :: map()
  @type generation_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Generates Elixir module source code from a lexicon definition.

  ## Parameters

  - `lexicon`: A map containing the parsed lexicon definition

  ## Returns

  - `{:ok, source_code}` - The generated Elixir module as a string
  - `{:error, reason}` - If generation fails
  """
  @spec generate_module(lexicon()) :: generation_result()
  def generate_module(%{"id" => id, "defs" => defs} = lexicon) do
    module_name = id_to_module_name(id)
    schemas = generate_schemas(defs)

    source =
      build_module_source(
        module_name,
        id,
        lexicon["description"],
        schemas
      )

    {:ok, source}
  rescue
    error -> {:error, {:generation_failed, Exception.message(error)}}
  end

  def generate_module(_), do: {:error, :invalid_lexicon_format}

  @doc """
  Converts a lexicon ID (e.g., "app.bsky.feed.post") to an Elixir module name.

  ## Examples

      iex> Generator.id_to_module_name("app.bsky.feed.post")
      "ProtoRune.Lexicon.App.Bsky.Feed.Post"

      iex> Generator.id_to_module_name("com.atproto.repo.strongRef")
      "ProtoRune.Lexicon.Com.Atproto.Repo.StrongRef"
  """
  @spec id_to_module_name(String.t()) :: String.t()
  def id_to_module_name(id) do
    parts =
      id
      |> String.split(".")
      |> Enum.map(&Macro.camelize/1)

    "ProtoRune.Lexicon." <> Enum.join(parts, ".")
  end

  @doc """
  Calculates the file path for a generated module based on its ID.

  ## Examples

      iex> Generator.module_file_path("app.bsky.feed.post", "/path/to/generated")
      "/path/to/generated/app/bsky/feed/post.ex"
  """
  @spec module_file_path(String.t(), String.t()) :: String.t()
  def module_file_path(id, output_dir) do
    path_parts = String.split(id, ".")
    relative_path = Path.join(path_parts) <> ".ex"
    Path.join(output_dir, relative_path)
  end

  # Private functions

  defp generate_schemas(defs) when is_map(defs) do
    Enum.reduce(defs, %{}, fn {name, def}, acc ->
      case generate_schema_for_def(name, def) do
        {:ok, schema} -> Map.put(acc, name, schema)
        {:error, _reason} -> acc
      end
    end)
  end

  defp generate_schema_for_def(name, %{"type" => "record", "record" => record_def} = def) do
    with {:ok, schema} <- TypeMapper.map_type(record_def) do
      {:ok,
       %{
         name: name,
         type: :record,
         schema: schema,
         description: def["description"],
         key: def["key"]
       }}
    end
  end

  defp generate_schema_for_def(name, %{"type" => "query"} = def) do
    params_schema =
      if params = def["parameters"],
        do: TypeMapper.map_object_type(params),
        else: {:ok, %{}}

    output_schema =
      if output = def["output"],
        do: TypeMapper.map_type(output["schema"]),
        else: {:ok, :any}

    with {:ok, params} <- params_schema,
         {:ok, output} <- output_schema do
      {:ok,
       %{
         name: name,
         type: :query,
         parameters: params,
         output: output,
         description: def["description"]
       }}
    end
  end

  defp generate_schema_for_def(name, %{"type" => "procedure"} = def) do
    input_schema =
      if input = def["input"],
        do: TypeMapper.map_type(input["schema"]),
        else: {:ok, :any}

    output_schema =
      if output = def["output"],
        do: TypeMapper.map_type(output["schema"]),
        else: {:ok, :any}

    with {:ok, input} <- input_schema,
         {:ok, output} <- output_schema do
      {:ok,
       %{
         name: name,
         type: :procedure,
         input: input,
         output: output,
         description: def["description"]
       }}
    end
  end

  defp generate_schema_for_def(name, %{"type" => "object"} = def) do
    with {:ok, schema} <- TypeMapper.map_object_type(def) do
      {:ok,
       %{
         name: name,
         type: :object,
         schema: schema,
         description: def["description"]
       }}
    end
  end

  defp generate_schema_for_def(name, def) do
    # For other types (token, subscription, etc.), try to map as-is
    with {:ok, schema} <- TypeMapper.map_type(def) do
      {:ok,
       %{
         name: name,
         type: :other,
         schema: schema,
         description: def["description"]
       }}
    end
  end

  defp build_module_source(module_name, id, description, schemas) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated module for #{id} lexicon.

      #{escape_doc(description)}

      This module was automatically generated from the ATProto lexicon definition.
      Do not edit this file manually.
      \"\"\"

      import Peri

    #{build_schemas_code(schemas)}

    #{build_validation_functions(schemas, module_name)}
    end
    """
  end

  defp escape_doc(nil), do: "No description available."

  defp escape_doc(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(~s("""), ~s(\\"\\"\\"))
  end

  defp build_schemas_code(schemas) do
    Enum.map_join(schemas, "\n\n", fn {name, schema_def} ->
      build_schema_code(name, schema_def)
    end)
  end

  defp build_schema_code(name, %{type: :record, schema: schema, description: desc}) do
    schema_formatted = inspect(schema, pretty: true, limit: :infinity)
    doc_text = if desc, do: escape_doc(desc), else: "Record schema for #{name}."

    """
      @doc \"\"\"
      #{doc_text}
      \"\"\"
      defschema :#{name}, #{schema_formatted}
    """
  end

  defp build_schema_code(name, %{type: :query, parameters: params, output: output, description: desc}) do
    params_formatted = inspect(params, pretty: true, limit: :infinity)
    output_formatted = inspect(output, pretty: true, limit: :infinity)
    doc_text = if desc, do: escape_doc(desc), else: "Query schema for #{name}."

    """
      @doc \"\"\"
      #{doc_text}
      \"\"\"
      defschema :#{name}_params, #{params_formatted}

      defschema :#{name}_output, #{output_formatted}
    """
  end

  defp build_schema_code(name, %{type: :procedure, input: input, output: output, description: desc}) do
    input_formatted = inspect(input, pretty: true, limit: :infinity)
    output_formatted = inspect(output, pretty: true, limit: :infinity)
    doc_text = if desc, do: escape_doc(desc), else: "Procedure schema for #{name}."

    """
      @doc \"\"\"
      #{doc_text}
      \"\"\"
      defschema :#{name}_input, #{input_formatted}

      defschema :#{name}_output, #{output_formatted}
    """
  end

  defp build_schema_code(name, %{type: :object, schema: schema, description: desc}) do
    schema_formatted = inspect(schema, pretty: true, limit: :infinity)
    doc_text = if desc, do: escape_doc(desc), else: "Object schema for #{name}."

    """
      @doc \"\"\"
      #{doc_text}
      \"\"\"
      defschema :#{name}, #{schema_formatted}
    """
  end

  defp build_schema_code(name, %{schema: schema, description: desc}) do
    schema_formatted = inspect(schema, pretty: true, limit: :infinity)
    doc_text = if desc, do: escape_doc(desc), else: "Schema for #{name}."

    """
      @doc \"\"\"
      #{doc_text}
      \"\"\"
      defschema :#{name}, #{schema_formatted}
    """
  end

  defp build_validation_functions(schemas, module_name) do
    main_schema = Map.get(schemas, "main")

    if main_schema do
      """
        @doc \"\"\"
        Validates data against the main schema.

        ## Examples

            iex> #{module_name}.validate(data)
            {:ok, validated_data}

            iex> #{module_name}.validate!(data)
            validated_data
        \"\"\"
        def validate(data), do: main(data)

        def validate!(data), do: main!(data)
      """
    else
      ""
    end
  end

  @doc """
  Generates all lexicon modules from a directory of JSON files.

  ## Parameters

  - `lexicons_dir`: Directory containing lexicon JSON files
  - `output_dir`: Directory where generated modules will be written

  ## Returns

  - `{:ok, count}` - Number of modules generated
  - `{:error, reason}` - If generation fails
  """
  @spec generate_all(String.t(), String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def generate_all(lexicons_dir, output_dir) do
    with {:ok, files} <- list_lexicon_files(lexicons_dir),
         {:ok, lexicons} <- parse_lexicons(files),
         :ok <- ensure_output_dir(output_dir) do
      generate_and_write_modules(lexicons, output_dir)
    end
  end

  defp list_lexicon_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        json_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.map(&Path.join(dir, &1))

        {:ok, json_files}

      {:error, reason} ->
        {:error, {:directory_error, dir, reason}}
    end
  end

  defp parse_lexicons(files) do
    results =
      Enum.map(files, fn file ->
        with {:ok, content} <- File.read(file) do
          Jason.decode(content)
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      lexicons = Enum.map(results, fn {:ok, lex} -> lex end)
      {:ok, lexicons}
    else
      {:error, {:parse_errors, errors}}
    end
  end

  defp ensure_output_dir(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end

  defp generate_and_write_modules(lexicons, output_dir) do
    results =
      Enum.map(lexicons, fn lexicon ->
        with {:ok, source} <- generate_module(lexicon),
             file_path = module_file_path(lexicon["id"], output_dir),
             :ok <- ensure_parent_dir(file_path),
             :ok <- File.write(file_path, source) do
          {:ok, file_path}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, length(results)}
    else
      {:error, {:write_errors, errors}}
    end
  end

  defp ensure_parent_dir(file_path) do
    file_path
    |> Path.dirname()
    |> File.mkdir_p()
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end
end
