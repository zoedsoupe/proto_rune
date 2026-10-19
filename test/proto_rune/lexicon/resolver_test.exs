defmodule ProtoRune.Lexicon.ResolverTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Lexicon.Resolver

  @doc_id "com.example.post"

  defp entries(docs), do: Map.new(docs, fn doc -> {doc["id"], doc} end)

  defp post_doc do
    %{
      "id" => @doc_id,
      "defs" => %{
        "main" => %{
          "type" => "record",
          "record" => %{
            "type" => "object",
            "required" => ["reply"],
            "properties" => %{"reply" => %{"type" => "ref", "ref" => "#replyRef"}}
          }
        },
        "replyRef" => %{
          "type" => "object",
          "required" => ["root"],
          "properties" => %{"root" => %{"type" => "string"}}
        }
      }
    }
  end

  describe "resolve_def/3 - ref spellings" do
    test "inlines a local #name ref" do
      doc = post_doc()

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc]))

      reply = resolved["record"]["properties"]["reply"]

      assert reply == %{
               "type" => "object",
               "required" => ["root"],
               "properties" => %{"root" => %{"type" => "string"}}
             }
    end

    test "inlines a cross-lexicon main ref" do
      strong_ref = %{
        "id" => "com.atproto.repo.strongRef",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "required" => ["uri", "cid"],
            "properties" => %{
              "uri" => %{"type" => "string"},
              "cid" => %{"type" => "string"}
            }
          }
        }
      }

      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"subject" => %{"type" => "ref", "ref" => "com.atproto.repo.strongRef"}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc, strong_ref]))

      subject = resolved["properties"]["subject"]
      assert subject["properties"]["uri"] == %{"type" => "string"}
      assert subject["properties"]["cid"] == %{"type" => "string"}
    end

    test "inlines a cross-lexicon nsid#name ref against the document it came from" do
      # The pulled-in definition's own local refs resolve against its own
      # document, not the one the walk started in.
      label_defs = %{
        "id" => "com.atproto.label.defs",
        "defs" => %{
          "selfLabels" => %{
            "type" => "object",
            "properties" => %{"values" => %{"type" => "ref", "ref" => "#selfLabel"}}
          },
          "selfLabel" => %{
            "type" => "object",
            "properties" => %{"val" => %{"type" => "string"}}
          }
        }
      }

      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "labels" => %{"type" => "ref", "ref" => "com.atproto.label.defs#selfLabels"}
            }
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc, label_defs]))

      values = resolved["properties"]["labels"]["properties"]["values"]
      assert values["properties"]["val"] == %{"type" => "string"}
    end

    test "degrades a ref naming a def the document does not have" do
      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"x" => %{"type" => "ref", "ref" => "#missing"}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc]))
      assert resolved["properties"]["x"] == %{"type" => "unknown"}
    end

    test "degrades a ref naming a lexicon the entries table does not hold" do
      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"x" => %{"type" => "ref", "ref" => "org.missing.defs#thing"}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc]))
      assert resolved["properties"]["x"] == %{"type" => "unknown"}
    end

    test "returns an error for a def name the document does not have" do
      doc = post_doc()
      assert {:error, {:unknown_def, "nope"}} = Resolver.resolve_def(doc, "nope", entries([doc]))
    end
  end

  describe "resolve_def/3 - cycles" do
    test "a self-referencing def degrades the cyclic edge instead of hanging" do
      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "child" => %{"type" => "ref", "ref" => "#node"}
            }
          },
          "node" => %{
            "type" => "object",
            "properties" => %{
              "child" => %{"type" => "ref", "ref" => "#node"}
            }
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc]))

      # The first level inlines; the edge back into #node is cut.
      first_child = resolved["properties"]["child"]
      assert first_child["properties"]["child"] == %{"type" => "unknown"}
    end

    test "two lexicons referring to each other terminate" do
      a = %{
        "id" => "com.example.a",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"to_b" => %{"type" => "ref", "ref" => "com.example.b"}}
          }
        }
      }

      b = %{
        "id" => "com.example.b",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"to_a" => %{"type" => "ref", "ref" => "com.example.a"}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(a, "main", entries([a, b]))

      # a -> b inlines; b -> a inlines once more and the edge back into
      # a's main is the one cut.
      round_trip = resolved["properties"]["to_b"]["properties"]["to_a"]
      assert round_trip["properties"]["to_b"] == %{"type" => "unknown"}
    end

    test "diamond refs resolve in both branches" do
      # seen only accumulates down a path: two siblings referencing the same
      # def both inline it.
      shared = %{
        "id" => "com.example.shared",
        "defs" => %{
          "main" => %{"type" => "object", "properties" => %{"v" => %{"type" => "string"}}}
        }
      }

      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "x" => %{"type" => "ref", "ref" => "com.example.shared"},
              "y" => %{"type" => "ref", "ref" => "com.example.shared"}
            }
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc, shared]))

      assert resolved["properties"]["x"]["properties"]["v"] == %{"type" => "string"}
      assert resolved["properties"]["y"]["properties"]["v"] == %{"type" => "string"}
    end
  end

  describe "resolve_def/3 - unions" do
    defp union_doc do
      %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "content" => %{"type" => "union", "refs" => ["#textBlock", "org.other.block"]}
            }
          },
          "textBlock" => %{
            "type" => "object",
            "required" => ["text"],
            "properties" => %{"text" => %{"type" => "string"}}
          }
        }
      }
    end

    defp other_doc do
      %{
        "id" => "org.other.block",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "required" => ["url"],
            "properties" => %{"url" => %{"type" => "string"}}
          }
        }
      }
    end

    test "keeps variants keyed by the ref as the lexicon wrote it" do
      {:ok, resolved} = Resolver.resolve_def(union_doc(), "main", entries([union_doc(), other_doc()]))

      union = resolved["properties"]["content"]
      assert MapSet.new(Map.keys(union["variants"])) == MapSet.new(["#textBlock", "org.other.block"])
      assert union["variants"]["#textBlock"]["properties"]["text"] == %{"type" => "string"}
      assert union["variants"]["org.other.block"]["properties"]["url"] == %{"type" => "string"}
    end

    test "pins object members with the $type the wire data carries" do
      {:ok, resolved} = Resolver.resolve_def(union_doc(), "main", entries([union_doc(), other_doc()]))

      union = resolved["properties"]["content"]

      # A local "#textBlock" ref carries the id of the document defining it.
      text_block = union["variants"]["#textBlock"]
      assert text_block["properties"]["$type"] == %{"type" => "string", "const" => "com.example.post#textBlock"}
      assert "$type" in text_block["required"]

      # A cross-lexicon ref carries the ref itself.
      other = union["variants"]["org.other.block"]
      assert other["properties"]["$type"] == %{"type" => "string", "const" => "org.other.block"}
      assert "$type" in other["required"]
    end

    test "drops members whose ref cannot be followed" do
      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"content" => %{"type" => "union", "refs" => ["org.missing.block"]}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc]))
      assert resolved["properties"]["content"]["variants"] == %{}
    end

    test "a cyclic member contributes no variant" do
      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"content" => %{"type" => "union", "refs" => ["#loop"]}}
          },
          "loop" => %{
            "type" => "object",
            "properties" => %{"content" => %{"type" => "union", "refs" => ["#loop"]}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "loop", entries([doc]))

      # The member inlines once; the union inside it names #loop again, which
      # is now a cycle and contributes no variant.
      inner_union =
        resolved["properties"]["content"]["variants"]["#loop"]["properties"]["content"]

      assert inner_union["variants"] == %{}
    end

    test "an object member pulled in by a ref inside a union keeps its own union's local defs" do
      # The recordWithMedia pattern: a union member object whose properties
      # hold another union with local refs.
      doc = %{
        "id" => @doc_id,
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"content" => %{"type" => "union", "refs" => ["#media"]}}
          },
          "media" => %{
            "type" => "object",
            "properties" => %{"part" => %{"type" => "union", "refs" => ["#part"]}}
          },
          "part" => %{
            "type" => "object",
            "properties" => %{"u" => %{"type" => "string"}}
          }
        }
      }

      {:ok, resolved} = Resolver.resolve_def(doc, "main", entries([doc]))

      media = resolved["properties"]["content"]["variants"]["#media"]
      part = media["properties"]["part"]["variants"]["#part"]
      assert part["properties"]["u"] == %{"type" => "string"}
      assert part["properties"]["$type"] == %{"type" => "string", "const" => "com.example.post#part"}
    end
  end

  describe "annotate_type/2" do
    test "adds the $type constant and marks it required" do
      node = %{
        "type" => "object",
        "required" => ["text"],
        "properties" => %{"text" => %{"type" => "string"}}
      }

      annotated = Resolver.annotate_type(node, "app.bsky.embed.images")

      assert annotated["properties"]["$type"] == %{"type" => "string", "const" => "app.bsky.embed.images"}
      assert annotated["required"] == ["$type", "text"]
    end

    test "does not duplicate $type in required" do
      node = %{"type" => "object", "required" => ["$type"], "properties" => %{}}
      annotated = Resolver.annotate_type(node, "x.y")
      assert annotated["required"] == ["$type"]
    end

    test "passes non-object nodes through" do
      assert Resolver.annotate_type(%{"type" => "token"}, "x.y") == %{"type" => "token"}
    end
  end
end
