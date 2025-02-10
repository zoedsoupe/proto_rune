defmodule ProtoRune.Lexicon.Loader do
  @moduledoc """
  Handles loading and parsing of AT Protocol lexicon files.

  This module is responsible for:
  - Reading lexicon JSON files
  - Validating lexicon structure
  - Normalizing lexicon data
  """

  alias ProtoRune.Lexicon.DependencyGraph

  @type lexicon :: %{
          id: String.t(),
          defs: map(),
          description: String.t() | nil,
          version: integer()
        }

  @doc """
  Loads and parses all lexicon files from the given directory.

  Returns a list of normalized lexicon structures.
  """
  @spec load(String.t()) :: {:ok, {[lexicon()], DependencyGraph.graph()}} | {:error, term()}
  def load(dir) when is_binary(dir) do
    with {:ok, files} <- list_lexicon_files(dir),
         {:ok, lexicons} <- parse_lexicons(files),
         normalized_lexicons = normalize_lexicons(lexicons),
         {:ok, graph} <- DependencyGraph.build(normalized_lexicons) do
      {:ok, {normalized_lexicons, graph}}
    end
  end

  defp list_lexicon_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files = Enum.filter(files, &String.ends_with?(&1, ".json"))
        {:ok, Enum.map(files, &Path.join(dir, &1))}

      {:error, reason} ->
        {:error, {:directory_error, dir, reason}}
    end
  end

  defp parse_lexicons(files) do
    lexicons =
      files
      |> Enum.map(&parse_lexicon_file/1)
      |> Enum.reject(&match?({:error, _}, &1))

    if length(lexicons) == length(files) do
      {:ok, lexicons}
    else
      errors = Enum.filter(lexicons, &match?({:error, _}, &1))
      {:error, {:parse_errors, errors}}
    end
  end

  defp parse_lexicon_file(path) do
    with {:ok, content} <- File.read(path),
         {:ok, json} <- Jason.decode(content),
         :ok <- validate_lexicon_structure(json) do
      json
    else
      {:error, reason} -> {:error, {:file_error, path, reason}}
    end
  end

  defp validate_lexicon_structure(json) do
    # Basic structure validation - we'll expand this
    required_fields = ~w(lexicon id defs)

    if Enum.all?(required_fields, &Map.has_key?(json, &1)) do
      :ok
    else
      missing = Enum.reject(required_fields, &Map.has_key?(json, &1))
      {:error, {:missing_fields, missing}}
    end
  end

  defp normalize_lexicons(lexicons) do
    Enum.map(lexicons, &normalize_lexicon/1)
  end

  defp normalize_lexicon(lexicon) do
    %{
      id: lexicon["id"],
      defs: normalize_defs(lexicon["defs"]),
      description: lexicon["description"],
      version: lexicon["lexicon"]
    }
  end

  defp normalize_defs(defs) when is_map(defs) do
    Map.new(defs, fn {key, def} ->
      {key, normalize_def(def)}
    end)
  end

  defp normalize_def(%{"type" => type} = def) do
    Map.merge(
      %{
        type: type,
        description: def["description"]
      },
      normalize_type_specific(type, def)
    )
  end

  defp normalize_type_specific("record", def) do
    %{
      properties: def["properties"] || %{},
      required: def["required"] || []
    }
  end

  defp normalize_type_specific("query", def) do
    %{
      parameters: def["parameters"],
      output: def["output"],
      errors: def["errors"] || []
    }
  end

  defp normalize_type_specific("procedure", def) do
    %{
      parameters: def["parameters"],
      input: def["input"],
      output: def["output"],
      errors: def["errors"] || []
    }
  end

  defp normalize_type_specific(_, _), do: %{}
end
