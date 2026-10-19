defmodule ProtoRune.LexiconTest do
  use ProtoRune.TestCase, async: false

  alias ProtoRune.Atproto.Repo
  alias ProtoRune.Lexicon

  # The tests below swap the process-independent lexicon cache, so the module
  # does not run concurrently with itself.
  @cache_key {Lexicon, :cache}

  setup do
    Lexicon.unload()
    on_exit(&Lexicon.unload/0)

    :ok
  end

  describe "load/0 over the vendored corpus" do
    @tag :corpus
    test "every lexicon of the vendored corpus loads without error" do
      # Loading is strict: :ok means every def of every lexicon resolved into
      # a valid Peri schema. The corpus is the submodule pinned at
      # @atproto/api 0.17.3; bump the count when the submodule moves.
      assert :ok = Lexicon.load()

      cache = :persistent_term.get(@cache_key)
      assert map_size(cache.entries) == 292
      assert map_size(cache.schemas) == 292

      # Every lexicon translates at least one def.
      assert Enum.all?(Map.values(cache.schemas), &(&1 != %{}))
    end

    @tag :corpus
    test "no resolved schema contains a leftover unresolved $ref" do
      assert :ok = Lexicon.load()

      cache = :persistent_term.get(@cache_key)

      Enum.each(cache.schemas, fn {nsid, defs} ->
        Enum.each(defs, fn {def_name, schema} ->
          assert_no_refs(schema, nsid, def_name)
        end)
      end)
    end

    @tag :corpus
    test "app.bsky.feed.post validates a real post-shaped map and rejects a malformed one" do
      assert {:ok, post} = Lexicon.schema_for("app.bsky.feed.post")

      valid = %{
        "$type" => "app.bsky.feed.post",
        text: "hello from the lexicon loader",
        createdAt: "2026-01-01T00:00:00.000Z",
        langs: ["en"],
        reply: %{
          root: %{uri: "at://did:plc:x/app.bsky.feed.post/1", cid: "bafyabc"},
          parent: %{uri: "at://did:plc:x/app.bsky.feed.post/2", cid: "bafydef"}
        },
        embed: %{
          "$type" => "app.bsky.embed.images",
          images: [%{alt: "a bridge", image: %{"$link" => "bafyimg", "$type" => "blob"}}]
        },
        facets: [
          %{
            index: %{byteStart: 0, byteEnd: 4},
            features: [%{"$type" => "app.bsky.richtext.facet#link", uri: "https://example.com"}]
          }
        ]
      }

      assert {:ok, validated} = Peri.validate(post, valid)
      assert validated[:"$type"] == "app.bsky.feed.post"
      assert validated[:text] == "hello from the lexicon loader"

      assert {:error, _} = Peri.validate(post, Map.put(valid, :text, 42))
      assert {:error, _} = Peri.validate(post, Map.delete(valid, :createdAt))

      # A union member naming none of the declared variants is rejected.
      bad_embed = Map.put(valid, :embed, %{"$type" => "app.bsky.embed.unknown", images: []})
      assert {:error, _} = Peri.validate(post, bad_embed)
    end
  end

  describe "schema_for/1" do
    test "returns the main def schema for a bare NSID" do
      :ok = Lexicon.load()
      assert {:ok, schema} = Lexicon.schema_for("app.bsky.feed.post")
      assert is_map(schema)
      assert schema[:text] == {:required, {:string, {:max, 3000}}}
    end

    test "pins a record's $type to its NSID" do
      :ok = Lexicon.load()
      assert {:ok, schema} = Lexicon.schema_for("app.bsky.feed.post")
      assert schema[:"$type"] == {:required, {:literal, "app.bsky.feed.post"}}
    end

    test "returns a named def schema for {nsid, def}" do
      :ok = Lexicon.load()

      assert {:ok, reply_ref} = Lexicon.schema_for({"app.bsky.feed.post", "replyRef"})

      # The strongRef the refs name resolves inline, cross-NSID.
      strong_ref = %{uri: {:required, :string}, cid: {:required, :string}}
      assert reply_ref[:root] == {:required, strong_ref}
      assert reply_ref[:parent] == {:required, strong_ref}
    end

    test "a named def carries no $type pin" do
      :ok = Lexicon.load()
      assert {:ok, reply_ref} = Lexicon.schema_for({"app.bsky.feed.post", "replyRef"})
      refute Map.has_key?(reply_ref, :"$type")
    end

    test "exposes query parameters as the def's schema" do
      :ok = Lexicon.load()

      assert {:ok, params} = Lexicon.schema_for("app.bsky.feed.getPosts")
      assert params[:uris] == {:required, {:list, :string, [max: 25]}}
    end

    test "unknown lexicon, unknown def and invalid target" do
      :ok = Lexicon.load()

      assert {:error, :unknown_lexicon} = Lexicon.schema_for("org.unknown.lexicon")
      assert {:error, {:unknown_def, "nope"}} = Lexicon.schema_for({"app.bsky.feed.post", "nope"})
      assert {:error, :invalid_target} = Lexicon.schema_for(42)
    end

    test "loads the vendored corpus on first use" do
      assert {:ok, _} = Lexicon.schema_for("app.bsky.feed.post")
      assert %{} != :persistent_term.get(@cache_key).schemas
    end
  end

  describe "schema_for!/1" do
    test "returns the schema directly" do
      :ok = Lexicon.load()
      schema = Lexicon.schema_for!("app.bsky.feed.post")
      assert schema[:text] == {:required, {:string, {:max, 3000}}}
    end

    test "raises for an unknown lexicon" do
      :ok = Lexicon.load()

      assert_raise ArgumentError, ~r/no lexicon schema/, fn ->
        Lexicon.schema_for!("org.unknown.lexicon")
      end
    end
  end

  describe "load/1 with a host lexicon directory" do
    test "loads custom lexicons and replaces the previous cache" do
      dir = write_fixtures(%{"blog.myapp.post" => post_lexicon(), "blog.myapp.tag" => tag_lexicon()})

      assert :ok = Lexicon.load(dir)

      cache = :persistent_term.get(@cache_key)
      assert MapSet.new(Map.keys(cache.schemas)) == MapSet.new(["blog.myapp.post", "blog.myapp.tag"])

      # The vendored corpus is gone: a load swaps the whole cache.
      assert {:error, :unknown_lexicon} = Lexicon.schema_for("app.bsky.feed.post")

      {:ok, schema} = Lexicon.schema_for("blog.myapp.post")
      valid = %{"$type" => "blog.myapp.post", text: "hi", createdAt: "2026-01-01T00:00:00.000Z"}
      assert {:ok, _} = Peri.validate(schema, valid)
      assert {:error, _} = Peri.validate(schema, Map.put(valid, :text, 9))
    end

    test "resolves refs across the loaded set" do
      dir = write_fixtures(%{"blog.myapp.post" => post_lexicon(), "blog.myapp.tag" => tag_lexicon()})
      assert :ok = Lexicon.load(dir)

      {:ok, schema} = Lexicon.schema_for("blog.myapp.post")

      valid = %{
        "$type" => "blog.myapp.post",
        text: "hi",
        createdAt: "2026-01-01T00:00:00.000Z",
        tags: [%{"$type" => "blog.myapp.tag", tag: "elixir"}]
      }

      assert {:ok, _} = Peri.validate(schema, valid)

      bad_tag = Map.put(valid, :tags, [%{"$type" => "blog.myapp.tag", tag: 9}])
      assert {:error, _} = Peri.validate(schema, bad_tag)
    end

    test "a cyclic reference pair degrades instead of failing the load" do
      a = %{
        "lexicon" => 1,
        "id" => "blog.myapp.a",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"to_b" => %{"type" => "ref", "ref" => "blog.myapp.b"}}
          }
        }
      }

      b = %{
        "lexicon" => 1,
        "id" => "blog.myapp.b",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"to_a" => %{"type" => "ref", "ref" => "blog.myapp.a"}}
          }
        }
      }

      dir = write_fixtures(%{"blog.myapp.a" => a, "blog.myapp.b" => b})
      assert :ok = Lexicon.load(dir)
      assert {:ok, _} = Lexicon.schema_for("blog.myapp.a")
    end

    test "a ref to a lexicon outside the set degrades that subtree" do
      lex = post_lexicon()

      with_dangling =
        put_in(lex, ["defs", "main", "record", "properties", "foreign"], %{
          "type" => "ref",
          "ref" => "org.missing.defs#thing"
        })

      dir = write_fixtures(%{"blog.myapp.post" => with_dangling})
      assert :ok = Lexicon.load(dir)

      {:ok, schema} = Lexicon.schema_for("blog.myapp.post")
      assert schema[:foreign] == :any
    end

    test "fails loudly on invalid json, missing id and unreadable files" do
      dir = tmp_dir()
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "broken.json"), "{not json")

      assert {:error, {:invalid_json, path, _}} = Lexicon.load(dir)
      assert String.ends_with?(path, "broken.json")

      no_id = %{"lexicon" => 1, "defs" => %{}}
      File.rm!(Path.join(dir, "broken.json"))
      File.write!(Path.join(dir, "no_id.json"), JSON.encode!(no_id))
      assert {:error, {:invalid_lexicon, path, :missing_id_or_defs}} = Lexicon.load(dir)
      assert String.ends_with?(path, "no_id.json")

      File.rm!(Path.join(dir, "no_id.json"))
      File.mkdir!(Path.join(dir, "subdir.json"))
      assert {:error, {:unreadable, path, _}} = Lexicon.load(dir)
      assert String.ends_with?(path, "subdir.json")
    end

    test "an empty directory is an error, not an empty load" do
      dir = tmp_dir()
      File.mkdir_p!(dir)

      assert {:error, {:no_lexicon_files, ^dir}} = Lexicon.load(dir)
    end

    test "fails loudly when a def does not resolve into a valid schema" do
      broken = %{
        "lexicon" => 1,
        "id" => "blog.myapp.broken",
        "defs" => %{
          "main" => %{"type" => "wat"}
        }
      }

      dir = write_fixtures(%{"blog.myapp.broken" => broken})

      assert {:error, {:invalid_def, "blog.myapp.broken", "main", {:unsupported_type, _}}} =
               Lexicon.load(dir)
    end
  end

  describe "integration with Repo.create_record" do
    @session %ProtoRune.Atproto.Session{
      access_jwt: "token123",
      refresh_jwt: "refresh123",
      did: "did:plc:test",
      handle: "alice.test",
      service_url: "https://pds.test/xrpc"
    }

    test "a schema_for! schema validates the record through the write path" do
      :ok = Lexicon.load()

      http =
        fake_http(fn method, url, opts ->
          send(self(), {:request, method, url, opts})

          {:ok, %{status: 200, body: %{"uri" => "at://did:plc:test/app.bsky.feed.post/abc", "cid" => "bafy123"}}}
        end)

      record = %{
        "$type" => "app.bsky.feed.post",
        text: "hello",
        createdAt: "2026-01-01T00:00:00.000Z"
      }

      opts = [schema: Lexicon.schema_for!("app.bsky.feed.post"), http: http]

      assert {:ok, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "app.bsky.feed.post", record: record},
                 opts
               )

      assert_received {:request, :post, _url, sent_opts}
      sent_record = Keyword.fetch!(sent_opts, :json)[:record]
      assert sent_record[:"$type"] == "app.bsky.feed.post"
      assert sent_record[:text] == "hello"
      assert sent_record[:createdAt] == "2026-01-01T00:00:00.000Z"
    end

    test "a malformed record is rejected before any request is made" do
      :ok = Lexicon.load()

      http = fake_http(fn _method, _url, _opts -> flunk("no request expected") end)

      record = %{"$type" => "app.bsky.feed.post", text: 42, createdAt: "2026-01-01T00:00:00.000Z"}
      opts = [schema: Lexicon.schema_for!("app.bsky.feed.post"), http: http]

      assert {:error, _} =
               Repo.create_record(
                 @session,
                 %{repo: "did:plc:test", collection: "app.bsky.feed.post", record: record},
                 opts
               )
    end
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "proto_rune_lexicon_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp write_fixtures(lexicons) do
    dir = tmp_dir()
    File.mkdir_p!(dir)

    for {name, lexicon} <- lexicons do
      File.write!(Path.join(dir, "#{name}.json"), JSON.encode!(lexicon))
    end

    dir
  end

  defp post_lexicon do
    %{
      "lexicon" => 1,
      "id" => "blog.myapp.post",
      "defs" => %{
        "main" => %{
          "type" => "record",
          "key" => "tid",
          "record" => %{
            "type" => "object",
            "required" => ["text", "createdAt"],
            "properties" => %{
              "text" => %{"type" => "string", "maxLength" => 100},
              "createdAt" => %{"type" => "string", "format" => "datetime"},
              "tags" => %{"type" => "array", "items" => %{"type" => "ref", "ref" => "blog.myapp.tag"}}
            }
          }
        }
      }
    }
  end

  defp tag_lexicon do
    %{
      "lexicon" => 1,
      "id" => "blog.myapp.tag",
      "defs" => %{
        "main" => %{
          "type" => "object",
          "required" => ["tag"],
          "properties" => %{"tag" => %{"type" => "string"}}
        }
      }
    }
  end

  # Fails the test naming the lexicon and def holding the leftover ref.
  defp assert_no_refs({:ref, name}, nsid, def_name) do
    flunk("leftover unresolved $ref #{inspect(name)} in #{nsid}##{def_name}")
  end

  defp assert_no_refs(map, nsid, def_name) when is_map(map) do
    map |> Map.values() |> Enum.each(&assert_no_refs(&1, nsid, def_name))
  end

  defp assert_no_refs(list, nsid, def_name) when is_list(list) do
    Enum.each(list, &assert_no_refs(&1, nsid, def_name))
  end

  defp assert_no_refs(tuple, nsid, def_name) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.each(&assert_no_refs(&1, nsid, def_name))
  end

  defp assert_no_refs(_term, _nsid, _def_name), do: :ok
end
