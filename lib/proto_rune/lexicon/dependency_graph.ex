defmodule ProtoRune.Lexicon.DependencyGraph do
  @moduledoc """
  Analyzes dependencies between AT Protocol lexicons and determines generation order.

  This module builds a directed graph of lexicon dependencies using Erlang's :digraph
  module and provides utilities for determining the optimal order for code generation,
  handling circular dependencies through a multi-phase approach.
  """

  @type node_t :: String.t()
  @type edge :: {node_t(), node_t()}
  @type graph :: :digraph.graph()

  @doc """
  Builds a dependency graph from a list of normalized lexicons.

  Returns a graph structure containing nodes (lexicon IDs) and edges (dependencies).
  The graph can then be analyzed for cycles and generation ordering.
  """
  @spec build([ProtoRune.Lexicon.Loader.lexicon()]) :: {:ok, graph()} | {:error, term()}
  def build(lexicons) do
    # Remove :acyclic option to allow cycles
    graph = :digraph.new()

    try do
      # Add all lexicons as nodes first
      Enum.each(lexicons, &add_lexicon_node(graph, &1))

      # Then add all dependencies as edges
      with :ok <- add_all_dependencies(lexicons, graph) do
        {:ok, graph}
      end
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Returns all circular dependencies found in the graph.

  This is useful for reporting and documentation purposes, to make developers
  aware of which modules have interdependencies.
  """
  @spec get_circular_dependencies(graph()) :: [{node(), node()}]
  def get_circular_dependencies(graph) do
    graph
    |> :digraph_utils.strong_components()
    |> Enum.filter(&(length(&1) > 1))
    |> Enum.flat_map(&component_edges(graph, &1))
    |> Enum.uniq()
  end

  @doc """
  Determines the optimal generation order based on dependencies.

  Returns a map containing ordered lists of modules for each generation phase:
  - :type_declarations - Basic type and module declarations
  - :type_implementations - Complete type implementations with references
  - :schemas - Schema implementations and validation logic
  """
  @spec generation_phases(graph()) :: %{
          type_declarations: [node()],
          type_implementations: [node()],
          schemas: [node()]
        }
  def generation_phases(graph) do
    # Find strongly connected components (cycles)
    components = :digraph_utils.strong_components(graph)

    # Separate cyclic and non-cyclic components
    {cyclic, non_cyclic} = Enum.split_with(components, &(length(&1) > 1))

    # All nodes in cyclic components need type declarations
    cyclic_nodes = List.flatten(cyclic)
    non_cyclic_nodes = List.flatten(non_cyclic)

    # Get dependency-ordered list of all nodes
    ordered_nodes =
      case :digraph_utils.topsort(graph) do
        false -> non_cyclic_nodes
        nodes -> Enum.filter(nodes, &(&1 in non_cyclic_nodes))
      end

    # All nodes in cycles must be declared first
    # Then implement in dependency order
    %{
      type_declarations: cyclic_nodes,
      type_implementations: cyclic_nodes ++ ordered_nodes,
      schemas: cyclic_nodes ++ ordered_nodes
    }
  end

  # Private Functions

  defp add_lexicon_node(graph, lexicon) do
    :digraph.add_vertex(graph, lexicon.id)
  end

  defp add_all_dependencies(lexicons, graph) do
    result =
      Enum.reduce_while(lexicons, :ok, fn lexicon, :ok ->
        case add_lexicon_dependencies(graph, lexicon) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end

  defp add_lexicon_dependencies(graph, lexicon) do
    refs = extract_refs_from_defs(lexicon.defs)

    try do
      Enum.each(refs, fn ref ->
        :digraph.add_edge(graph, lexicon.id, ref)
      end)

      :ok
    rescue
      error -> {:error, {:dependency_error, lexicon.id, error}}
    end
  end

  defp extract_refs_from_defs(defs) when is_map(defs) do
    Enum.flat_map(defs, fn {_key, def} ->
      extract_refs_from_def(def)
    end)
  end

  defp extract_refs_from_def(%{type: "ref", ref: ref}), do: [ref]

  defp extract_refs_from_def(%{properties: props}) when is_map(props) do
    Enum.flat_map(props, fn {_key, prop} -> extract_refs_from_def(prop) end)
  end

  defp extract_refs_from_def(_), do: []

  defp component_edges(graph, component) do
    for v1 <- component,
        v2 <- component,
        v1 != v2,
        path = :digraph.get_path(graph, v1, v2),
        path != false do
      {v1, v2}
    end
  end
end
