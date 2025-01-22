defmodule Mix.Tasks.GenSchemasTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.GenSchemas
  alias Mix.Tasks.GenSchemas.Context
  alias Mix.Tasks.GenSchemas.DependencyResolver
  alias Mix.Tasks.GenSchemas.Generator
  alias Mix.Tasks.GenSchemas.Loader
  alias Mix.Tasks.GenSchemas.TypeMapper
  alias Mix.Tasks.GenSchemas.Utils

  @moduletag capture_log: true

  setup do
    # Create a temporary directory for generated files
    temp_dir = Path.join(System.tmp_dir!(), "gen_schemas_test_#{:os.system_time(:millisecond)}")
    File.mkdir_p!(temp_dir)

    on_exit(fn ->
      # Clean up temporary directory
      File.rm_rf!(temp_dir)
    end)

    {:ok, temp_dir: temp_dir}
  end

  describe "Loader" do
    test "loads lexicons from files" do
      lexicon_content = """
      {
        "lexicon": 1,
        "id": "com.example.test",
        "defs": {
          "main": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "age": { "type": "integer" }
            },
            "required": ["name"]
          }
        }
      }
      """

      file_path = Path.join(System.tmp_dir!(), "test_lexicon.json")
      File.write!(file_path, lexicon_content)

      {:ok, lexicons} = Loader.load_lexicons([file_path])

      assert length(lexicons) == 1
      assert Enum.at(lexicons, 0)["id"] == "com.example.test"

      File.rm!(file_path)
    end

    test "builds defs_map from lexicons" do
      lexicon = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "age" => %{"type" => "integer"}
            },
            "required" => ["name"]
          }
        }
      }

      {:ok, defs_map} = Loader.build_defs_map([lexicon])

      assert Map.has_key?(defs_map, {"com.example.test", "main"})
    end
  end

  describe "DependencyResolver" do
    test "sorts definitions based on dependencies" do
      defs_map = %{
        {"com.example.test", "main"} => %{
          "type" => "object",
          "properties" => %{
            "profile" => %{"type" => "ref", "ref" => "#profile"}
          }
        },
        {"com.example.test", "profile"} => %{
          "type" => "object",
          "properties" => %{
            "bio" => %{"type" => "string"}
          }
        }
      }

      {:ok, sorted_defs} = DependencyResolver.sort_definitions(defs_map)

      assert sorted_defs == [
               {"com.example.test", "profile"},
               {"com.example.test", "main"}
             ]
    end
  end

  describe "TypeMapper" do
    test "maps simple types to Elixir types" do
      assert TypeMapper.type_to_elixir(%{
               context: %Context{},
               lexicon_id: "com.example",
               definition: %{"type" => "string"}
             }) == "String.t()"

      assert TypeMapper.type_to_elixir(%{
               context: %Context{},
               lexicon_id: "com.example",
               definition: %{"type" => "integer"}
             }) == "integer()"

      assert TypeMapper.type_to_elixir(%{
               context: %Context{},
               lexicon_id: "com.example",
               definition: %{"type" => "boolean"}
             }) == "boolean()"
    end

    test "maps array types" do
      assert TypeMapper.type_to_elixir(%{
               context: %Context{},
               lexicon_id: "com.example",
               definition: %{
                 "type" => "array",
                 "items" => %{"type" => "string"}
               }
             }) == "list(String.t())"
    end

    test "handles refs to other types", %{temp_dir: temp_dir} do
      context = %Context{
        defs_map: %{
          {"com.example", "profile"} => %{"type" => "object"}
        },
        generated_modules: MapSet.new(),
        output_dir: temp_dir
      }

      assert TypeMapper.type_to_elixir(%{
               context: context,
               lexicon_id: "com.example",
               definition: %{
                 "type" => "ref",
                 "ref" => "#profile"
               }
             }) == "ProtoRune.Com.Example.Profile.t()"
    end
  end

  describe "Generator" do
    test "generates object modules", %{temp_dir: temp_dir} do
      context = %Context{
        defs_map: %{},
        generated_modules: MapSet.new(),
        output_dir: temp_dir
      }

      definition = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      Generator.generate_object_module(%{
        context: context,
        lexicon_id: "com.example",
        name: "User",
        definition: definition
      })

      module_file = Path.join([temp_dir, "com", "example", "user.ex"])
      assert File.exists?(module_file)

      module_content = File.read!(module_file)
      assert module_content =~ "defmodule ProtoRune.Com.Example.User do"
      assert module_content =~ "@type t :: %__MODULE__{"
      assert module_content =~ "name: String.t()"
      assert module_content =~ "age: integer()"
    end

    test "generates query modules", %{temp_dir: temp_dir} do
      context = %Context{
        defs_map: %{
          {"com.example", "user"} => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"}
            }
          }
        },
        generated_modules: MapSet.new(),
        output_dir: temp_dir
      }

      definition = %{
        "type" => "query",
        "parameters" => %{
          "type" => "params",
          "properties" => %{
            "userId" => %{"type" => "string"}
          },
          "required" => ["userId"]
        },
        "output" => %{
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "user" => %{"type" => "ref", "ref" => "#user"}
            }
          }
        }
      }

      Generator.generate_query_module(%{
        context: context,
        lexicon_id: "com.example",
        name: "GetUser",
        definition: definition
      })

      module_file = Path.join([temp_dir, "com", "example", "get_user.ex"])
      assert File.exists?(module_file)

      module_content = File.read!(module_file)
      assert module_content =~ "defmodule ProtoRune.Com.Example.GetUser do"
      assert module_content =~ "@type input :: %{user_id: String.t()}"
      assert module_content =~ "@type output :: %{user: ProtoRune.Com.Example.User.t()}"
    end
  end

  describe "Utils" do
    test "parses refs correctly" do
      assert Utils.parse_ref("com.example", "#profile") == {"com.example", "profile"}
      assert Utils.parse_ref("com.example", "com.other#profile") == {"com.other", "profile"}
      assert Utils.parse_ref("com.example", "com.other") == {"com.other", "main"}
    end

    test "converts field names to atoms" do
      assert Utils.field_name_to_atom("userName") == :user_name
    end
  end

  describe "Integration test" do
    test "generates schemas from lexicons", %{temp_dir: temp_dir} do
      lexicon_content = """
      {
        "lexicon": 1,
        "id": "com.example.user",
        "defs": {
          "main": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "age": { "type": "integer" },
              "profile": { "type": "ref", "ref": "#profile" }
            },
            "required": ["name"]
          },
          "profile": {
            "type": "object",
            "properties": {
              "bio": { "type": "string" }
            }
          }
        }
      }
      """

      # Write lexicon to a dedicated directory
      lexicon_dir = Path.join(temp_dir, "lexicons")
      File.mkdir_p!(lexicon_dir)
      lexicon_file = Path.join(lexicon_dir, "user_lexicon.json")
      File.write!(lexicon_file, lexicon_content)

      GenSchemas.run(["--path", lexicon_dir, "--output-dir", temp_dir])

      user_module_file = Path.join([temp_dir, "com", "example", "user.ex"])
      profile_module_file = Path.join([temp_dir, "com", "example", "user", "profile.ex"])

      assert File.exists?(user_module_file)
      assert File.exists?(profile_module_file)

      user_module_content = File.read!(user_module_file)
      assert user_module_content =~ "defmodule ProtoRune.Com.Example.User do"
      assert user_module_content =~ "profile: ProtoRune.Com.Example.User.Profile.t()"

      profile_module_content = File.read!(profile_module_file)
      assert profile_module_content =~ "defmodule ProtoRune.Com.Example.User.Profile do"

      File.rm!(lexicon_file)
    end

    @tag skip: true
    test "processes real lexicon definitions", %{temp_dir: temp_dir} do
      lexicon_dir = Path.expand("../../../priv/lexicons", __DIR__)

      if File.dir?(lexicon_dir) do
        temp_lexicon_dir = Path.join(temp_dir, "lexicons")
        File.mkdir_p!(temp_lexicon_dir)

        # Clean target dir before copying to avoid the file already exists issue
        File.rm_rf!(temp_lexicon_dir)
        File.cp_r!(lexicon_dir, temp_lexicon_dir)

        GenSchemas.run(["--path", temp_lexicon_dir, "--output-dir", temp_dir])

        expected_modules = [
          Path.join([temp_dir, "app", "bsky", "actor", "get_profile.ex"]),
          Path.join([temp_dir, "app", "bsky", "actor", "defs", "profile_view_detailed.ex"])
        ]

        for module_file <- expected_modules do
          assert File.exists?(module_file)
        end
      else
        IO.puts("Skipping real lexicon definitions test: directory #{lexicon_dir} does not exist.")

        assert true
      end
    end
  end
end
