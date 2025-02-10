defmodule ProtoRune.Lexicon.LoaderTest do
  use ExUnit.Case, async: true

  alias ProtoRune.Lexicon.Loader

  @fixtures_dir "test/fixtures/lexicons"

  setup do
    File.mkdir_p!(@fixtures_dir)
    on_exit(fn -> File.rm_rf!(@fixtures_dir) end)
  end

  test "loads valid lexicon files" do
    write_fixture("post.json", %{
      "lexicon" => 1,
      "id" => "app.bsky.feed.post",
      "defs" => %{
        "main" => %{
          "type" => "record",
          "properties" => %{
            "text" => %{"type" => "string"},
            "createdAt" => %{"type" => "datetime"}
          }
        }
      }
    })

    assert {:ok, {[lexicon], _}} = Loader.load(@fixtures_dir)
    assert lexicon.id == "app.bsky.feed.post"
    assert get_in(lexicon.defs, ["main", :type]) == "record"
  end

  test "loads valid lexicon files with dependency graph" do
    write_fixture("post.json", %{
      "lexicon" => 1,
      "id" => "app.bsky.feed.post",
      "defs" => %{
        "main" => %{
          "type" => "record",
          "properties" => %{
            "text" => %{"type" => "string"},
            "createdAt" => %{"type" => "datetime"},
            "author" => %{"type" => "ref", "ref" => "app.bsky.actor.profile"}
          }
        }
      }
    })

    write_fixture("profile.json", %{
      "lexicon" => 1,
      "id" => "app.bsky.actor.profile",
      "defs" => %{
        "main" => %{
          "type" => "record",
          "properties" => %{
            "name" => %{"type" => "string"}
          }
        }
      }
    })

    assert {:ok, {lexicons, _graph}} = Loader.load(@fixtures_dir)
    assert length(lexicons) == 2

    # Verify first lexicon structure is maintained
    post = Enum.find(lexicons, &(&1.id == "app.bsky.feed.post"))
    assert get_in(post.defs, ["main", :type]) == "record"
  end

  test "handles missing required fields" do
    write_fixture("invalid.json", %{
      "lexicon" => 1
    })

    assert {:error, {:parse_errors, _}} = Loader.load(@fixtures_dir)
  end

  defp write_fixture(name, content) do
    path = Path.join(@fixtures_dir, name)
    File.write!(path, Jason.encode!(content))
  end
end
