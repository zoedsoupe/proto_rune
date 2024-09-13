defmodule Mix.Tasks.GenSchemas do
  @moduledoc false

  use Mix.Task

  @shortdoc "Generates Elixir modules for schemas in defs.json"

  def run(["--file", def_file_path]) do
    with {:ok, content} <- maybe_read_file_content(def_file_path),
         {:ok, lexicon} <- Jason.decode(content) do
      Enum.each(lexicon["defs"], fn {name, def} ->
        generate_schema_module(lexicon["id"], name, def)
      end)

      Mix.shell().info("Schema modules generated successfully!")
    else
      {:error, err} -> Mix.shell().error("Failed with reason: #{err}!")
    end
  end

  def run(_) do
    Mix.shell().error("Wrong usage! Need to pass the --file flag!")
  end

  defp maybe_read_file_content(file_path) do
    file_path
    |> Path.expand()
    |> File.read()
  end

  def generate_schema_module(id, name, %{"type" => "string", "knownValues" => _} = t) do
    context = to_module_context(id)
    module_name = to_module_name(id, name)

    typespec = type_to_elixir(context, t)

    module_contents = """
    defmodule #{module_name} do
      @moduledoc "Generated schema for #{name}"

      @type t :: #{typespec}
    end
    """

    # Write the module to a file
    file_path =
      Path.join(["lib", Macro.underscore(context), "#{Macro.underscore(name)}.ex"])

    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, module_contents)
  end

  def generate_schema_module(id, name, %{"type" => "array", "items" => _} = t) do
    context = to_module_context(id)
    module_name = to_module_name(id, name)

    typespec = type_to_elixir(context, t)

    module_contents = """
    defmodule #{module_name} do
      @moduledoc "Generated schema for #{name}"

      @type t :: #{typespec}
    end
    """

    # Write the module to a file
    file_path =
      Path.join(["lib", Macro.underscore(context), "#{Macro.underscore(name)}.ex"])

    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, module_contents)
  end

  def generate_schema_module(id, name, schema_def) do
    context = to_module_context(id)
    module_name = to_module_name(id, name)

    # Prepare struct and typespecs
    fields = extract_fields(name, schema_def)
    required = Enum.map(schema_def["required"] || [], &String.to_atom/1)
    typespecs = generate_typespecs(context, name, schema_def)

    module_contents = """
    defmodule #{module_name} do
      @moduledoc "Generated schema for #{name}"

      #{if required != [], do: "@enforce_keys #{inspect(required)}", else: ""}
      defstruct #{inspect(fields)}

      @type t :: %__MODULE__{
              #{Enum.join(typespecs, ",\n              ")}
            }
    end
    """

    # Write the module to a file
    file_path =
      Path.join(["lib", Macro.underscore(context), "#{Macro.underscore(name)}.ex"])

    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, module_contents)
  end

  defp to_module_name(id, name) do
    context = to_module_context(id)

    String.replace("#{context}.#{Macro.camelize(name)}", "Elixir.", "")
  end

  defp to_module_context("app.bsky" <> _), do: Bsky
  defp to_module_context("chat.bsky" <> _), do: Bsky
  defp to_module_context("com.atproto" <> _), do: Atproto
  defp to_module_context("tools.ozone" <> _), do: Ozone

  defp extract_fields(_name, %{"properties" => properties}) do
    Enum.map(properties, fn {field_name, _props} ->
      field_name |> Macro.underscore() |> String.to_atom()
    end)
  end

  defp generate_typespecs(id, _, %{"properties" => properties}) do
    Enum.map(properties, fn {field_name, props} ->
      name = field_name |> Macro.underscore() |> String.to_atom()
      "#{name}: #{type_to_elixir(id, props)}"
    end)
  end

  defp generate_typespecs(_id, name, %{"type" => "string", "knownValues" => enum}) do
    name = name |> Macro.underscore() |> String.to_atom()

    ["#{name}: #{Enum.map_join(enum, " | ", &"#{Macro.underscore(":#{&1}")}")}"]
  end

  defp type_to_elixir(_, %{"type" => "string", "knownValues" => enum}) do
    Enum.map_join(enum, " | ", &"#{Macro.underscore(":#{&1}")}")
  end

  defp type_to_elixir(_, %{"type" => "string"}), do: "String.t()"
  defp type_to_elixir(_, %{"type" => "integer"}), do: "integer"
  defp type_to_elixir(_, %{"type" => "boolean"}), do: "boolean"

  defp type_to_elixir(id, %{"type" => "array", "items" => item_props}) do
    "list(#{type_to_elixir(id, item_props)})"
  end

  defp type_to_elixir(id, %{"type" => "union", "refs" => refs}) do
    Enum.map_join(refs, " | ", &"#{ref_to_module(id, &1)}.t()")
  end

  defp type_to_elixir(id, %{"type" => "ref", "ref" => ref}) do
    "#{ref_to_module(id, ref)}.t()"
  end

  # Handle refs to other modules
  defp ref_to_module(id, ref) do
    ref
    |> String.split("#")
    |> List.last()
    |> Macro.camelize()
    |> then(&"#{id}.#{&1}")
    |> String.replace("Elixir.", "")
  end
end
