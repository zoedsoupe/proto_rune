defmodule ATProto.Identity.Cache do
  @moduledoc """
  Provides caching for AT Protocol identity resolution results.

  This module maintains two ETS tables:
  - handle_cache: Maps handles to DIDs with TTL
  - did_cache: Stores DID documents with TTL

  The cache automatically expires entries and provides
  concurrent access with proper cleanup.
  """

  use GenServer

  require Logger

  @type cache_key :: String.t()
  @type cache_value :: term()
  @type ttl :: non_neg_integer()

  # Default TTLs
  @default_handle_ttl to_timeout(hour: 1)
  @default_did_ttl to_timeout(hour: 24)

  # Server state
  defmodule State do
    @moduledoc false
    defstruct [:handle_table, :did_table, :handle_ttl, :did_ttl, :max_size]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a cached DID for a handle.
  Returns {:ok, did} if found and not expired, otherwise {:error, reason}.
  """
  @spec get_did(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def get_did(handle) do
    with {:ok, did, _meta} <- lookup(:handle_cache, handle) do
      {:ok, did}
    end
  end

  @doc """
  Gets a cached DID document.
  Returns {:ok, doc} if found and not expired, otherwise {:error, reason}.
  """
  @spec get_did_doc(String.t()) :: {:ok, map()} | {:error, atom()}
  def get_did_doc(did) do
    with {:ok, doc, _meta} <- lookup(:did_cache, did) do
      {:ok, doc}
    end
  end

  @doc """
  Stores a handle -> DID mapping in the cache.
  """
  @spec put_did(String.t(), String.t(), keyword()) :: :ok
  def put_did(handle, did, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_handle_ttl)
    GenServer.cast(__MODULE__, {:put, :handle_cache, handle, did, ttl})
  end

  @doc """
  Stores a DID document in the cache.
  """
  @spec put_did_doc(String.t(), map(), keyword()) :: :ok
  def put_did_doc(did, doc, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_did_ttl)
    GenServer.cast(__MODULE__, {:put, :did_cache, did, doc, ttl})
  end

  @doc """
  Invalidates cached data for a handle.
  """
  @spec invalidate_handle(String.t()) :: :ok
  def invalidate_handle(handle) do
    GenServer.cast(__MODULE__, {:invalidate, :handle_cache, handle})
  end

  @doc """
  Invalidates cached data for a DID.
  """
  @spec invalidate_did(String.t()) :: :ok
  def invalidate_did(did) do
    GenServer.cast(__MODULE__, {:invalidate, :did_cache, did})
  end

  @doc """
  Returns cache statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    handle_table = :ets.new(:handle_cache, [:named_table, :set, :public, read_concurrency: true])
    did_table = :ets.new(:did_cache, [:named_table, :set, :public, read_concurrency: true])

    state = %State{
      handle_table: handle_table,
      did_table: did_table,
      handle_ttl: Keyword.get(opts, :handle_ttl, @default_handle_ttl),
      did_ttl: Keyword.get(opts, :did_ttl, @default_did_ttl),
      max_size: Keyword.get(opts, :max_size, 10_000)
    }

    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_cast({:put, table, key, value, ttl}, state) do
    expires_at = System.system_time(:millisecond) + ttl
    metadata = %{expires_at: expires_at}

    true = :ets.insert(table, {key, value, metadata})
    maybe_enforce_size_limit(table, state.max_size)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:invalidate, table, key}, state) do
    true = :ets.delete(table, key)
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired(state.handle_table)
    cleanup_expired(state.did_table)
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      handle_cache: table_stats(state.handle_table),
      did_cache: table_stats(state.did_table)
    }

    {:reply, stats, state}
  end

  # Private Functions

  defp lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, metadata}] ->
        if expired?(metadata) do
          {:error, :expired}
        else
          {:ok, value, metadata}
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp expired?(%{expires_at: expires_at}) do
    System.system_time(:millisecond) > expires_at
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, to_timeout(minute: 5))
  end

  defp cleanup_expired(table) do
    now = System.system_time(:millisecond)

    # Delete expired entries
    :ets.select_delete(table, [{{:_, :_, %{expires_at: :"$1"}}, [{:<, :"$1", now}], [true]}])
  end

  defp maybe_enforce_size_limit(table, max_size) do
    if :ets.info(table, :size) > max_size do
      # Delete ~10% of oldest entries
      to_delete = div(max_size, 10)

      table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {_, _, %{expires_at: exp}} -> exp end)
      |> Enum.take(to_delete)
      |> Enum.each(fn {key, _, _} -> :ets.delete(table, key) end)
    end
  end

  defp table_stats(table) do
    %{
      size: :ets.info(table, :size),
      memory: :ets.info(table, :memory)
    }
  end
end
