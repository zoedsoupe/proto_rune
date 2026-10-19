defmodule ProtoRune.Lexicon do
  @moduledoc """
  Runtime loader for ATProto lexicon definitions.

  Reads lexicon JSON documents, inlines their `$ref` graph and hands back
  self-contained Peri schemas, keyed by NSID and def name. There is no code
  generation step: schemas are plain data terms built at runtime and validated
  with `Peri.validate/2` (or passed to `ProtoRune.Atproto.Repo` via the
  `:schema` option).

      # The vendored ATProto/Bluesky corpus, loaded on first use.
      {:ok, schema} = ProtoRune.Lexicon.schema_for("app.bsky.feed.post")

      # A specific def of a lexicon.
      {:ok, schema} = ProtoRune.Lexicon.schema_for({"app.bsky.feed.post", "replyRef"})

      # Explicit load of a host application's own lexicons.
      :ok = ProtoRune.Lexicon.load("priv/lexicons")

  Schemas are keyed by the lexicon's own property names as atoms, keeping the
  spelling the lexicon uses (`"createdAt"` becomes `:"createdAt"`), so
  validated records are atom-keyed wire shapes. Record schemas pin `"$type"`
  to their NSID, matching what the wire carries.

  The loaded set is cached once in `:persistent_term` and swapped atomically
  by `load/1`; there is no supervised process. The first `schema_for/1` call
  loads the vendored corpus shipped in this library's `priv/lexicons`; an
  explicit `load/1` replaces it with another directory or file list, which is
  how a host application brings its own lexicons. A load replaces the whole
  cache, so a host lexicon that references standard NSIDs should load a
  directory holding both.
  """

  alias ProtoRune.Lexicon.Loader

  @cache_key {__MODULE__, :cache}
  @main "main"

  @type nsid :: String.t()
  @type target :: nsid() | {nsid(), String.t()}

  @doc """
  The directory of the vendored lexicon corpus shipped with this library.
  """
  @spec vendored_dir :: String.t()
  def vendored_dir do
    case :code.priv_dir(:proto_rune) do
      {:error, reason} -> raise "proto_rune priv directory unavailable: #{inspect(reason)}"
      dir -> Path.join(dir, "lexicons")
    end
  end

  @doc """
  Loads the vendored lexicon corpus, replacing whatever was loaded.
  """
  @spec load :: :ok | {:error, term()}
  def load, do: load(vendored_dir())

  @doc """
  Loads lexicons from a directory or a list of files, replacing whatever was
  loaded.

  A source with no lexicon files at all is an error, not an empty load: a
  cache holding nothing answers `:unknown_lexicon` to every lookup and looks
  identical to a load that silently failed.
  """
  @spec load(Loader.source()) :: :ok | {:error, term()}
  def load(source) do
    case Loader.load(source) do
      {:ok, cache} ->
        :persistent_term.put(@cache_key, cache)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Drops the loaded lexicon cache. The next lookup loads the vendored corpus
  again.
  """
  @spec unload :: :ok
  def unload, do: :persistent_term.erase(@cache_key)

  @doc """
  Returns the Peri schema for a lexicon, or an error.

  The target is an NSID (shorthand for its `"main"` def) or an
  `{nsid, def_name}` tuple. Resolution is a map lookup over the loaded cache;
  when nothing is loaded, the vendored corpus is loaded first.

  ## Errors

    * `{:error, :unknown_lexicon}` - no loaded lexicon declares that NSID
    * `{:error, {:unknown_def, name}}` - the lexicon has no def with that name
    * `{:error, :invalid_target}` - the target is neither an NSID nor a tuple
    * `{:error, {:load_failed, reason}}` - the initial vendored load failed;
      a later call retries it
  """
  @spec schema_for(target()) :: {:ok, term()} | {:error, term()}
  def schema_for(nsid) when is_binary(nsid), do: schema_for({nsid, @main})

  def schema_for({nsid, def_name}) when is_binary(nsid) and is_binary(def_name) do
    with {:ok, cache} <- ensure_loaded(),
         {:ok, defs} <- fetch(cache.schemas, nsid, :unknown_lexicon) do
      fetch(defs, def_name, {:unknown_def, def_name})
    end
  end

  def schema_for(_target), do: {:error, :invalid_target}

  @doc """
  Same as `schema_for/1` but raises `ArgumentError` on any failure.
  """
  @spec schema_for!(target()) :: term()
  def schema_for!(target) do
    case schema_for(target) do
      {:ok, schema} -> schema
      {:error, reason} -> raise ArgumentError, "no lexicon schema for #{inspect(target)}: #{inspect(reason)}"
    end
  end

  defp ensure_loaded do
    case :persistent_term.get(@cache_key, :not_loaded) do
      %{schemas: _, entries: _} = cache -> {:ok, cache}
      _ -> load_vendored()
    end
  end

  defp load_vendored do
    case load() do
      :ok -> {:ok, :persistent_term.get(@cache_key)}
      {:error, reason} -> {:error, {:load_failed, reason}}
    end
  end

  defp fetch(map, key, error_reason) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, error_reason}
    end
  end
end
