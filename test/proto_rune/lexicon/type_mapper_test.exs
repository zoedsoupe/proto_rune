defmodule ProtoRune.Lexicon.TypeMapperTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Lexicon.TypeMapper

  describe "map_type/1 - primitives" do
    test "maps string type" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string"})
    end

    test "maps integer type" do
      assert {:ok, :integer} = TypeMapper.map_type(%{"type" => "integer"})
    end

    test "maps boolean type" do
      assert {:ok, :boolean} = TypeMapper.map_type(%{"type" => "boolean"})
    end

    test "maps float type" do
      assert {:ok, :float} = TypeMapper.map_type(%{"type" => "float"})
    end

    test "maps bytes type to string" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "bytes"})
    end

    test "maps unknown type to :any" do
      assert {:ok, :any} = TypeMapper.map_type(%{"type" => "unknown"})
    end

    test "maps blob type to :map" do
      assert {:ok, :map} = TypeMapper.map_type(%{"type" => "blob"})
    end

    test "maps token type to string" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "token"})
    end

    test "maps cid-link type to :map" do
      assert {:ok, :map} = TypeMapper.map_type(%{"type" => "cid-link"})
    end
  end

  describe "map_type/1 - string with formats" do
    test "maps datetime format to string (peri :datetime only accepts structs)" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "datetime"})
    end

    test "maps uri format" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "uri"})
    end

    test "maps did format" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "did"})
    end

    test "maps handle format" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "handle"})
    end

    test "maps at-uri format" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "at-uri"})
    end

    test "maps at-identifier format" do
      assert {:ok, :string} =
               TypeMapper.map_type(%{"type" => "string", "format" => "at-identifier"})
    end

    test "maps cid format" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "cid"})
    end

    test "maps language format" do
      assert {:ok, :string} = TypeMapper.map_type(%{"type" => "string", "format" => "language"})
    end
  end

  describe "map_type/1 - string with constraints" do
    test "maps string with maxLength" do
      assert {:ok, {:string, {:max, 100}}} =
               TypeMapper.map_type(%{"type" => "string", "maxLength" => 100})
    end

    test "maps string with minLength" do
      assert {:ok, {:string, {:min, 10}}} =
               TypeMapper.map_type(%{"type" => "string", "minLength" => 10})
    end

    test "maps string with both min and maxLength" do
      assert {:ok, {:string, [{:min, 10}, {:max, 100}]}} =
               TypeMapper.map_type(%{"type" => "string", "minLength" => 10, "maxLength" => 100})
    end

    test "maps string enum" do
      assert {:ok, {:enum, ["admin", "user", "guest"]}} =
               TypeMapper.map_type(%{"type" => "string", "enum" => ["admin", "user", "guest"]})
    end

    test "maps string const" do
      assert {:ok, {:literal, "active"}} =
               TypeMapper.map_type(%{"type" => "string", "const" => "active"})
    end
  end

  describe "map_type/1 - integer with constraints" do
    test "maps integer with range" do
      assert {:ok, {:integer, {:range, {1, 100}}}} =
               TypeMapper.map_type(%{"type" => "integer", "minimum" => 1, "maximum" => 100})
    end

    test "maps integer with minimum" do
      assert {:ok, {:integer, {:gte, 0}}} =
               TypeMapper.map_type(%{"type" => "integer", "minimum" => 0})
    end

    test "maps integer with maximum" do
      assert {:ok, {:integer, {:lte, 100}}} =
               TypeMapper.map_type(%{"type" => "integer", "maximum" => 100})
    end

    test "maps integer enum" do
      assert {:ok, {:enum, [1, 2, 3]}} =
               TypeMapper.map_type(%{"type" => "integer", "enum" => [1, 2, 3]})
    end

    test "maps integer const" do
      assert {:ok, {:literal, 42}} = TypeMapper.map_type(%{"type" => "integer", "const" => 42})
    end
  end

  describe "map_type/1 - float with constraints" do
    test "maps float with range" do
      assert {:ok, {:float, {:range, {min, max}}}} =
               TypeMapper.map_type(%{"type" => "float", "minimum" => 0.0, "maximum" => 1.0})

      assert min == 0.0
      assert max == 1.0
    end

    test "maps float with minimum" do
      assert {:ok, {:float, {:gte, min}}} =
               TypeMapper.map_type(%{"type" => "float", "minimum" => 0.0})

      assert min == 0.0
    end

    test "maps float with maximum" do
      assert {:ok, {:float, {:lte, 1.0}}} =
               TypeMapper.map_type(%{"type" => "float", "maximum" => 1.0})
    end
  end

  describe "map_type/1 - array" do
    test "maps array of strings" do
      assert {:ok, {:list, :string}} =
               TypeMapper.map_type(%{"type" => "array", "items" => %{"type" => "string"}})
    end

    test "maps array of integers" do
      assert {:ok, {:list, :integer}} =
               TypeMapper.map_type(%{"type" => "array", "items" => %{"type" => "integer"}})
    end

    test "maps nested arrays" do
      assert {:ok, {:list, {:list, :string}}} =
               TypeMapper.map_type(%{
                 "type" => "array",
                 "items" => %{"type" => "array", "items" => %{"type" => "string"}}
               })
    end

    test "keeps declared array length bounds" do
      assert {:ok, {:list, :string, [{:min, 1}, {:max, 3}]}} =
               TypeMapper.map_type(%{
                 "type" => "array",
                 "items" => %{"type" => "string"},
                 "minLength" => 1,
                 "maxLength" => 3
               })
    end
  end

  describe "map_type/1 - object" do
    test "maps simple object with properties" do
      assert {:ok, schema} =
               TypeMapper.map_type(%{
                 "type" => "object",
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "age" => %{"type" => "integer"}
                 }
               })

      assert is_map(schema)
      assert schema[:name] == :string
      assert schema[:age] == :integer
    end

    test "maps object with required fields" do
      assert {:ok, schema} =
               TypeMapper.map_type(%{
                 "type" => "object",
                 "required" => ["name"],
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "age" => %{"type" => "integer"}
                 }
               })

      assert schema[:name] == {:required, :string}
      assert schema[:age] == :integer
    end

    test "maps nested objects" do
      assert {:ok, schema} =
               TypeMapper.map_type(%{
                 "type" => "object",
                 "properties" => %{
                   "user" => %{
                     "type" => "object",
                     "properties" => %{
                       "name" => %{"type" => "string"}
                     }
                   }
                 }
               })

      assert is_map(schema[:user])
      assert schema[:user][:name] == :string
    end

    test "maps object with no declared properties to an empty schema" do
      assert {:ok, %{}} = TypeMapper.map_type(%{"type" => "object"})
    end

    test "maps params type like an object" do
      assert {:ok, schema} =
               TypeMapper.map_type(%{
                 "type" => "params",
                 "required" => ["repo"],
                 "properties" => %{"repo" => %{"type" => "string"}}
               })

      assert schema[:repo] == {:required, :string}
    end
  end

  describe "map_type/1 - refs arrive resolved" do
    test "refuses an unresolved ref node" do
      assert {:error, {:unresolved_ref, "com.atproto.repo.strongRef"}} =
               TypeMapper.map_type(%{"type" => "ref", "ref" => "com.atproto.repo.strongRef"})
    end

    test "refuses a refs-only union node" do
      assert {:error, {:unresolved_union, ["app.bsky.embed.images"]}} =
               TypeMapper.map_type(%{"type" => "union", "refs" => ["app.bsky.embed.images"]})
    end

    test "unwraps a ref to a record definition" do
      record_def = %{
        "type" => "record",
        "record" => %{
          "type" => "object",
          "properties" => %{"text" => %{"type" => "string"}}
        }
      }

      assert {:ok, %{text: :string}} = TypeMapper.map_type(record_def)
    end
  end

  describe "map_type/1 - union" do
    test "maps resolved variants to a oneof" do
      assert {:ok, {:oneof, variants}} =
               TypeMapper.map_type(%{
                 "type" => "union",
                 "variants" => %{
                   "app.bsky.embed.images" => %{
                     "type" => "object",
                     "properties" => %{"alt" => %{"type" => "string"}}
                   },
                   "app.bsky.embed.video" => %{
                     "type" => "object",
                     "properties" => %{"video" => %{"type" => "unknown"}}
                   }
                 }
               })

      assert length(variants) == 2
      assert Enum.all?(variants, &is_map/1)
      assert Enum.any?(variants, &(&1[:alt] == :string))
    end

    test "maps a fully degraded union to :any" do
      assert {:ok, :any} = TypeMapper.map_type(%{"type" => "union", "variants" => %{}})
    end
  end

  describe "map_type/1 - errors" do
    test "returns error for unsupported type" do
      assert {:error, {:unsupported_type, %{"type" => "custom"}}} =
               TypeMapper.map_type(%{"type" => "custom"})
    end

    test "returns error for invalid type definition" do
      assert {:error, :invalid_type_definition} = TypeMapper.map_type("not a map")
    end

    test "returns error for missing type field" do
      assert {:error, :invalid_type_definition} = TypeMapper.map_type(%{"foo" => "bar"})
    end
  end

  describe "map_object_type/1" do
    test "maps object with properties and required fields" do
      assert {:ok, schema} =
               TypeMapper.map_object_type(%{
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "email" => %{"type" => "string"}
                 },
                 "required" => ["email"]
               })

      assert schema[:name] == :string
      assert schema[:email] == {:required, :string}
    end

    test "maps object with no required fields" do
      assert {:ok, schema} =
               TypeMapper.map_object_type(%{
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "age" => %{"type" => "integer"}
                 }
               })

      assert schema[:name] == :string
      assert schema[:age] == :integer
    end

    test "returns error for invalid object definition" do
      assert {:error, :invalid_object_definition} = TypeMapper.map_object_type(%{})
    end
  end

  describe "integration - complex post lexicon" do
    test "maps a complete resolved post record" do
      post_def = %{
        "type" => "object",
        "required" => ["text", "createdAt"],
        "properties" => %{
          "text" => %{
            "type" => "string",
            "maxLength" => 3000,
            "maxGraphemes" => 300
          },
          "facets" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "uri" => %{"type" => "string"},
                "$type" => %{"type" => "string", "const" => "app.bsky.richtext.facet#link"}
              }
            }
          },
          "reply" => %{
            "type" => "object",
            "properties" => %{"root" => %{"type" => "unknown"}}
          },
          "embed" => %{
            "type" => "union",
            "variants" => %{
              "app.bsky.embed.images" => %{
                "type" => "object",
                "required" => ["$type"],
                "properties" => %{
                  "alt" => %{"type" => "string"},
                  "$type" => %{"type" => "string", "const" => "app.bsky.embed.images"}
                }
              }
            }
          },
          "langs" => %{
            "type" => "array",
            "maxLength" => 3,
            "items" => %{"type" => "string", "format" => "language"}
          },
          "createdAt" => %{
            "type" => "string",
            "format" => "datetime"
          }
        }
      }

      assert {:ok, schema} = TypeMapper.map_type(post_def)

      # Check required fields
      assert schema[:text] == {:required, {:string, {:max, 3000}}}
      assert schema[:createdAt] == {:required, :string}

      # Check optional fields
      assert {:list, facet_schema} = schema[:facets]
      assert facet_schema[:"$type"] == {:literal, "app.bsky.richtext.facet#link"}
      assert schema[:reply] == %{root: :any}
      assert {:oneof, [embed]} = schema[:embed]
      assert embed[:"$type"] == {:required, {:literal, "app.bsky.embed.images"}}
      assert schema[:langs] == {:list, :string, [max: 3]}
    end
  end
end
