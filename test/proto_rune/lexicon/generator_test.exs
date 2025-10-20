defmodule ProtoRune.Lexicon.GeneratorTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Lexicon.Generator

  @simple_lexicon %{
    "lexicon" => 1,
    "id" => "app.bsky.test.simple",
    "description" => "A simple test lexicon",
    "defs" => %{
      "main" => %{
        "type" => "record",
        "key" => "tid",
        "record" => %{
          "type" => "object",
          "required" => ["text"],
          "properties" => %{
            "text" => %{"type" => "string", "maxLength" => 300},
            "count" => %{"type" => "integer"}
          }
        }
      }
    }
  }

  @complex_lexicon %{
    "lexicon" => 1,
    "id" => "app.bsky.feed.post",
    "description" => "Record containing a Bluesky post.",
    "defs" => %{
      "main" => %{
        "type" => "record",
        "key" => "tid",
        "description" => "Main post record",
        "record" => %{
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
              "items" => %{"type" => "ref", "ref" => "app.bsky.richtext.facet"}
            },
            "createdAt" => %{
              "type" => "string",
              "format" => "datetime"
            }
          }
        }
      },
      "replyRef" => %{
        "type" => "object",
        "required" => ["root", "parent"],
        "properties" => %{
          "root" => %{"type" => "ref", "ref" => "com.atproto.repo.strongRef"},
          "parent" => %{"type" => "ref", "ref" => "com.atproto.repo.strongRef"}
        }
      }
    }
  }

  @query_lexicon %{
    "lexicon" => 1,
    "id" => "app.bsky.feed.getTimeline",
    "defs" => %{
      "main" => %{
        "type" => "query",
        "description" => "Get a timeline of posts",
        "parameters" => %{
          "type" => "params",
          "properties" => %{
            "limit" => %{
              "type" => "integer",
              "minimum" => 1,
              "maximum" => 100,
              "default" => 50
            },
            "cursor" => %{"type" => "string"}
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "type" => "object",
            "required" => ["feed"],
            "properties" => %{
              "feed" => %{
                "type" => "array",
                "items" => %{"type" => "ref", "ref" => "#feedViewPost"}
              },
              "cursor" => %{"type" => "string"}
            }
          }
        }
      }
    }
  }

  describe "id_to_module_name/1" do
    test "converts simple ID" do
      assert Generator.id_to_module_name("app.bsky.feed.post") ==
               "ProtoRune.Lexicon.App.Bsky.Feed.Post"
    end

    test "converts com.atproto ID" do
      assert Generator.id_to_module_name("com.atproto.repo.strongRef") ==
               "ProtoRune.Lexicon.Com.Atproto.Repo.StrongRef"
    end

    test "converts single part ID" do
      assert Generator.id_to_module_name("example") ==
               "ProtoRune.Lexicon.Example"
    end

    test "handles multi-word parts" do
      assert Generator.id_to_module_name("app.my_module.test_case") ==
               "ProtoRune.Lexicon.App.MyModule.TestCase"
    end
  end

  describe "module_file_path/2" do
    test "generates correct file path" do
      path = Generator.module_file_path("app.bsky.feed.post", "/tmp/generated")
      assert path == "/tmp/generated/app/bsky/feed/post.ex"
    end

    test "handles single part ID" do
      path = Generator.module_file_path("example", "/tmp/generated")
      assert path == "/tmp/generated/example.ex"
    end

    test "handles com.atproto ID" do
      path = Generator.module_file_path("com.atproto.repo.strongRef", "/tmp/generated")
      assert path == "/tmp/generated/com/atproto/repo/strongRef.ex"
    end
  end

  describe "generate_module/1" do
    test "generates module for simple lexicon" do
      assert {:ok, source} = Generator.generate_module(@simple_lexicon)

      assert source =~ "defmodule ProtoRune.Lexicon.App.Bsky.Test.Simple"
      assert source =~ "A simple test lexicon"
      assert source =~ "defschema :main"
      assert source =~ "import Peri"
      assert source =~ "def validate(data)"
      assert source =~ "def validate!(data)"
    end

    test "generates module for complex lexicon" do
      assert {:ok, source} = Generator.generate_module(@complex_lexicon)

      assert source =~ "defmodule ProtoRune.Lexicon.App.Bsky.Feed.Post"
      assert source =~ "Record containing a Bluesky post."
      assert source =~ "defschema :main"
      assert source =~ "defschema :replyRef"
      assert source =~ "text:"
      assert source =~ "createdAt:"
      assert source =~ "facets:"
    end

    test "generates module for query lexicon" do
      assert {:ok, source} = Generator.generate_module(@query_lexicon)

      assert source =~ "defmodule ProtoRune.Lexicon.App.Bsky.Feed.GetTimeline"
      assert source =~ "defschema :main_params"
      assert source =~ "defschema :main_output"
      assert source =~ "limit:"
      assert source =~ "cursor:"
    end

    test "includes required fields as {:required, type}" do
      assert {:ok, source} = Generator.generate_module(@simple_lexicon)
      assert source =~ "text: {:required"
    end

    test "includes optional fields without :required" do
      assert {:ok, source} = Generator.generate_module(@simple_lexicon)
      assert source =~ "count:"
      refute source =~ "count: {:required"
    end

    test "returns error for invalid lexicon" do
      assert {:error, :invalid_lexicon_format} = Generator.generate_module(%{})
    end

    test "returns error for lexicon without id" do
      assert {:error, :invalid_lexicon_format} =
               Generator.generate_module(%{"defs" => %{}})
    end

    test "returns error for lexicon without defs" do
      assert {:error, :invalid_lexicon_format} =
               Generator.generate_module(%{"id" => "test"})
    end
  end

  describe "generate_module/1 - generated code validity" do
    test "generated code can be parsed as valid Elixir" do
      assert {:ok, source} = Generator.generate_module(@simple_lexicon)

      # Try to parse the generated code
      assert {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "generated code includes proper moduledoc" do
      assert {:ok, source} = Generator.generate_module(@simple_lexicon)

      assert source =~ ~r/@moduledoc """/
      assert source =~ "Generated module for app.bsky.test.simple lexicon"
      assert source =~ "Do not edit this file manually"
    end

    test "generated code has proper indentation" do
      assert {:ok, source} = Generator.generate_module(@simple_lexicon)

      lines = String.split(source, "\n")

      # Check that defschema lines are indented
      schema_lines = Enum.filter(lines, &String.contains?(&1, "defschema"))
      assert Enum.all?(schema_lines, &String.starts_with?(&1, "  "))
    end
  end

  describe "generate_module/1 - type conversions" do
    test "converts string with constraints" do
      lexicon = %{
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "maxLength" => 100}
            }
          }
        }
      }

      assert {:ok, source} = Generator.generate_module(lexicon)
      assert source =~ "{:string, {:max, 100}}"
    end

    test "converts integer with range" do
      lexicon = %{
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "count" => %{"type" => "integer", "minimum" => 1, "maximum" => 100}
            }
          }
        }
      }

      assert {:ok, source} = Generator.generate_module(lexicon)
      assert source =~ "{:integer, {:range, {1, 100}}}"
    end

    test "converts datetime format" do
      lexicon = %{
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "createdAt" => %{"type" => "string", "format" => "datetime"}
            }
          }
        }
      }

      assert {:ok, source} = Generator.generate_module(lexicon)
      assert source =~ ":datetime"
    end

    test "converts arrays" do
      lexicon = %{
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "tags" => %{
                "type" => "array",
                "items" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, source} = Generator.generate_module(lexicon)
      assert source =~ "{:list, :string}"
    end

    test "converts refs" do
      lexicon = %{
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "ref" => %{"type" => "ref", "ref" => "com.atproto.repo.strongRef"}
            }
          }
        }
      }

      assert {:ok, source} = Generator.generate_module(lexicon)
      assert source =~ ~s({:ref, "com.atproto.repo.strongRef"})
    end

    test "converts unions" do
      lexicon = %{
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "embed" => %{
                "type" => "union",
                "refs" => ["app.bsky.embed.images", "app.bsky.embed.video"]
              }
            }
          }
        }
      }

      assert {:ok, source} = Generator.generate_module(lexicon)
      assert source =~ "{:oneof"
      assert source =~ "app.bsky.embed.images"
      assert source =~ "app.bsky.embed.video"
    end
  end

  describe "generate_all/2" do
    setup do
      # Create a temporary directory for testing
      tmp_dir = System.tmp_dir!()
      lexicons_dir = Path.join(tmp_dir, "test_lexicons_#{System.unique_integer([:positive])}")
      output_dir = Path.join(tmp_dir, "test_output_#{System.unique_integer([:positive])}")

      File.mkdir_p!(lexicons_dir)

      on_exit(fn ->
        File.rm_rf(lexicons_dir)
        File.rm_rf(output_dir)
      end)

      {:ok, lexicons_dir: lexicons_dir, output_dir: output_dir}
    end

    test "generates all modules from directory", %{
      lexicons_dir: lexicons_dir,
      output_dir: output_dir
    } do
      # Create test lexicon files
      File.write!(
        Path.join(lexicons_dir, "post.json"),
        Jason.encode!(@simple_lexicon)
      )

      File.write!(
        Path.join(lexicons_dir, "complex.json"),
        Jason.encode!(@complex_lexicon)
      )

      assert {:ok, 2} = Generator.generate_all(lexicons_dir, output_dir)

      # Check that files were created
      assert File.exists?(Path.join(output_dir, "app/bsky/test/simple.ex"))
      assert File.exists?(Path.join(output_dir, "app/bsky/feed/post.ex"))
    end

    test "returns error for non-existent directory", %{output_dir: output_dir} do
      assert {:error, {:directory_error, _, _}} =
               Generator.generate_all("/nonexistent/path", output_dir)
    end

    test "creates nested directories as needed", %{
      lexicons_dir: lexicons_dir,
      output_dir: output_dir
    } do
      File.write!(
        Path.join(lexicons_dir, "post.json"),
        Jason.encode!(@complex_lexicon)
      )

      assert {:ok, 1} = Generator.generate_all(lexicons_dir, output_dir)

      # Check that nested directories were created
      assert File.exists?(Path.join(output_dir, "app/bsky/feed/post.ex"))
    end

    test "handles empty directory", %{lexicons_dir: lexicons_dir, output_dir: output_dir} do
      assert {:ok, 0} = Generator.generate_all(lexicons_dir, output_dir)
    end
  end
end
