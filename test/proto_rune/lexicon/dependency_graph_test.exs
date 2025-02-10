defmodule ProtoRune.Lexicon.DependencyGraphTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Lexicon.DependencyGraph

  describe "build/1" do
    test "builds graph for independent lexicons" do
      lexicons = [
        %{id: "com.example.one", defs: %{}},
        %{id: "com.example.two", defs: %{}}
      ]

      assert {:ok, graph} = DependencyGraph.build(lexicons)
      assert length(:digraph.vertices(graph)) == 2
      assert length(:digraph.edges(graph)) == 0
    end

    test "detects direct dependencies" do
      lexicons = [
        %{
          id: "com.example.post",
          defs: %{
            "main" => %{
              type: "record",
              properties: %{
                "author" => %{type: "ref", ref: "com.example.profile"}
              }
            }
          }
        },
        %{id: "com.example.profile", defs: %{}}
      ]

      assert {:ok, graph} = DependencyGraph.build(lexicons)
      assert has_edge?(graph, "com.example.post", "com.example.profile")
    end

    test "detects circular dependencies" do
      lexicons = [
        %{
          id: "com.example.post",
          defs: %{
            "main" => %{
              type: "record",
              properties: %{
                "author" => %{type: "ref", ref: "com.example.profile"}
              }
            }
          }
        },
        %{
          id: "com.example.profile",
          defs: %{
            "main" => %{
              type: "record",
              properties: %{
                "latestPost" => %{type: "ref", ref: "com.example.post"}
              }
            }
          }
        }
      ]

      assert {:ok, graph} = DependencyGraph.build(lexicons)

      circular = DependencyGraph.get_circular_dependencies(graph)
      assert List.keyfind(circular, "com.example.post", 0)
      assert List.keyfind(circular, "com.example.profile", 0)
    end
  end

  describe "generation_phases/1" do
    test "orders independent lexicons" do
      {:ok, graph} =
        DependencyGraph.build([
          %{id: "one", defs: %{}},
          %{id: "two", defs: %{}}
        ])

      phases = DependencyGraph.generation_phases(graph)

      assert length(phases.type_declarations) == 0
      assert Enum.sort(phases.type_implementations) == ["one", "two"]
      assert Enum.sort(phases.schemas) == ["one", "two"]
    end

    test "handles circular dependencies across phases" do
      lexicons = [
        %{
          id: "post",
          defs: %{
            "main" => %{
              type: "record",
              properties: %{
                "author" => %{type: "ref", ref: "profile"}
              }
            }
          }
        },
        %{
          id: "profile",
          defs: %{
            "main" => %{
              type: "record",
              properties: %{
                "latestPost" => %{type: "ref", ref: "post"}
              }
            }
          }
        }
      ]

      assert {:ok, graph} = DependencyGraph.build(lexicons)
      phases = DependencyGraph.generation_phases(graph)

      # Both types must be declared before implementation
      assert Enum.sort(phases.type_declarations) == ["post", "profile"]
      assert Enum.sort(phases.type_implementations) == ["post", "profile"]
      assert Enum.sort(phases.schemas) == ["post", "profile"]
    end
  end

  defp has_edge?(graph, v1, v2) do
    case :digraph.get_path(graph, v1, v2) do
      false -> false
      _ -> true
    end
  end
end
