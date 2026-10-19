defmodule ProtoRune.Lexicon.Loader do
  @moduledoc """
  Loads lexicon JSON files, resolves every def and translates it into a
  self-contained Peri schema.

  `load/1` takes a directory (searched recursively for `*.json`) or an
  explicit list of file paths, indexes the documents by the NSID each file
  declares, and resolves every def of every document against that index.
  Loading is strict: a file that cannot be read or parsed, a document with
  no NSID, or a def that fails to resolve into a valid Peri schema fails the
  whole load with an `{:error, reason}` that names the offender. Failures
  are never silent.

  The result is a plain map, handed to `ProtoRune.Lexicon` to cache:

      %{
        entries: %{nsid => parsed lexicon document},
        schemas: %{nsid => %{def_name => peri_schema}}
      }
  """

  alias ProtoRune.Lexicon.Resolver
  alias ProtoRune.Lexicon.TypeMapper

  @type source :: Path.t() | [Path.t()]
  @type nsid :: String.t()
  @type cache :: %{
          entries: %{nsid() => map()},
          schemas: %{nsid() => %{String.t() => term()}}
        }

  @doc """
  Loads lexicons from a directory or a list of files.

  Directories are searched recursively for `*.json` files. Returns
  `{:ok, cache}` or `{:error, reason}` naming the first file or def that
  failed.
  """
  @spec load(source()) :: {:ok, cache()} | {:error, term()}
  def load(dir) when is_binary(dir) do
    files =
      dir
      |> Path.join("**/*.json")
      |> Path.wildcard()
      |> Enum.sort()

    case files do
      [] -> {:error, {:no_lexicon_files, dir}}
      files -> load(files)
    end
  end

  def load([]), do: {:error, :no_lexicon_files}

  def load(files) when is_list(files) do
    with {:ok, entries} <- read_all(files),
         {:ok, schemas} <- translate_all(entries) do
      {:ok, %{entries: entries, schemas: schemas}}
    end
  end

  defp read_all(files) do
    Enum.reduce_while(files, {:ok, %{}}, fn path, {:ok, acc} ->
      case read(path) do
        {:ok, nsid, doc} -> {:cont, {:ok, Map.put(acc, nsid, doc)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp read(path) do
    with {:ok, body} <- file_body(path),
         {:ok, doc} <- parsed(path, body),
         {:ok, nsid} <- nsid_of(path, doc) do
      {:ok, nsid, doc}
    end
  end

  defp file_body(path) do
    case File.read(path) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, {:unreadable, path, reason}}
    end
  end

  defp parsed(path, body) do
    case JSON.decode(body) do
      {:ok, doc} -> {:ok, doc}
      {:error, reason} -> {:error, {:invalid_json, path, reason}}
    end
  end

  defp nsid_of(_path, %{"id" => nsid, "defs" => defs}) when is_binary(nsid) and is_map(defs), do: {:ok, nsid}

  defp nsid_of(path, _doc), do: {:error, {:invalid_lexicon, path, :missing_id_or_defs}}

  defp translate_all(entries) do
    Enum.reduce_while(entries, {:ok, %{}}, fn {nsid, doc}, {:ok, acc} ->
      case translate_document(doc, entries, nsid) do
        {:ok, defs} -> {:cont, {:ok, Map.put(acc, nsid, defs)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp translate_document(%{"defs" => defs} = doc, entries, nsid) do
    Enum.reduce_while(defs, {:ok, %{}}, fn {def_name, def}, {:ok, acc} ->
      case translate_def(def, doc, entries, nsid, def_name) do
        {:ok, schema} ->
          {:cont, {:ok, Map.put(acc, def_name, schema)}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_def, nsid, def_name, reason}}}
      end
    end)
  end

  defp translate_def(%{"type" => "record"} = def, doc, entries, nsid, _def_name) do
    case Map.fetch(def, "record") do
      {:ok, body} ->
        body
        |> Resolver.resolve(doc, entries)
        # A record's `$type` on the wire is the NSID of its lexicon and the
        # Repo write path sends it, so it is pinned like a union member.
        |> Resolver.annotate_type(nsid)
        |> translate()

      :error ->
        {:error, :record_without_body}
    end
  end

  # Query, procedure and subscription defs are not data schemas; their
  # `parameters` object is the part a caller validates against, so that is
  # what the def's schema is. A procedure may omit parameters entirely.
  defp translate_def(%{"type" => kind, "parameters" => params}, doc, entries, _nsid, _def_name)
       when kind in ["query", "procedure", "subscription"] do
    translate(Resolver.resolve(params, doc, entries))
  end

  defp translate_def(%{"type" => kind}, _doc, _entries, _nsid, _def_name)
       when kind in ["query", "procedure", "subscription"] do
    {:ok, %{}}
  end

  defp translate_def(def, doc, entries, _nsid, _def_name) do
    translate(Resolver.resolve(def, doc, entries))
  end

  defp translate(resolved) do
    case TypeMapper.map_type(resolved) do
      {:ok, schema} ->
        case Peri.validate_schema(schema) do
          {:ok, _valid} -> {:ok, schema}
          {:error, reason} -> {:error, {:invalid_schema, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
