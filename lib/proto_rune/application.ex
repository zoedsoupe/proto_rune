defmodule ProtoRune.Application do
  @moduledoc """
  Library supervision for proto_rune.

  Supervises exactly one named Finch HTTP connection pool that backs
  `ProtoRune.HTTPClient` (the default `ProtoRune.HTTPClient.Adapters.Finch`
  adapter issues requests through it).

  This is the one cost of the Finch-over-Mint decision: Mint itself is
  process-less and would keep proto_rune a library with no supervision tree,
  but it ships no connection pool, and bot workloads (many short requests to
  the same PDS) need one. Hand-writing a pool around raw Mint was the
  over-engineering this swap removes, so the library owns a single pool
  process instead. The application is trivial: one pool, no consumers, no
  state.

  ## Pool configuration

  The pool is started under the `ProtoRune.Finch` name; every Finch option
  (`:pools`, `:pool_count`, ...) is read from the application environment:

      config :proto_rune, ProtoRune.Finch,
        pools: %{
          :default => [size: 10, count: 8]
        }

  See `Finch` for the full option list. Requests can bypass this pool
  entirely by injecting another adapter per call:

      HTTPClient.request(:get, url, adapter: MyAdapter)
  """

  use Application

  @impl true
  def start(_type, _args) do
    pool = ProtoRune.HTTPClient.Adapters.Finch.pool_name()
    opts = Application.get_env(:proto_rune, pool, [])
    children = [{Finch, Keyword.put_new(opts, :name, pool)}]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
