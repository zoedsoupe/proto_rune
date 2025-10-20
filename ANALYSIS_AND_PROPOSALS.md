# ProtoRune: Comprehensive Analysis & MVP Proposals

> **Document Status**: Analysis and recommendations for shipping ProtoRune v0.2.0 MVP
> **Date**: October 2025
> **Author**: Claude (ATProto & Elixir/OTP Specialist)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Reference Projects Deep Dive](#reference-projects-deep-dive)
4. [Proposal 1: Lexicon Code Generation](#proposal-1-lexicon-code-generation)
5. [Proposal 2: Public API Design](#proposal-2-public-api-design)
6. [Proposal 3: README & Documentation](#proposal-3-readme--documentation)
7. [Implementation Roadmap](#implementation-roadmap)

---

## Executive Summary

After analyzing proto_rune alongside jacquard (Rust), peri (Elixir), and atcute (TypeScript), I propose a **Peri-based code generation strategy** that:

- ✅ Avoids Ecto's complexity for dynamic ATProto types
- ✅ Provides runtime validation with compile-time generation
- ✅ Handles unions, unknowns, and refs elegantly
- ✅ Offers optional Ecto integration via `Peri.to_changeset!`

**Key Insight**: Your initial Ecto approach was getting complex because Ecto schemas are designed for database persistence, not dynamic protocol schemas. Peri is the perfect fit.

---

## Current State Analysis

### ProtoRune Structure (v0.1.2)

**Strengths:**
- Excellent RFC document (`rfc.md`) with clear architectural vision
- Good domain organization following ATProto's layers:
  - `lib/atproto/` - Core protocol (identity, repo, session)
  - `lib/bluesky/` - Bluesky-specific features
  - `lib/proto_rune/` - Framework code (bot, http_client, lexicon)
- Basic lexicon infrastructure in place:
  - `ProtoRune.Lexicon.Loader` (lib/proto_rune/lexicon/loader.ex:1)
  - `ProtoRune.Lexicon.DependencyGraph` (dependency resolution)
  - `ProtoRune.Lexicon.ModuleBuilder` (code generation stub)
- Peri v0.4.0-rc1 already as dependency (mix.exs:31)

**Current Challenges:**
```elixir
# From lib/proto_rune/lexicon/loader.ex
defp normalize_type_specific("record", def) do
  %{
    properties: def["properties"] || %{},
    required: def["required"] || []
  }
end
```
- ❌ Incomplete code generation - no actual module generation
- ❌ Attempted Ecto embedded schemas but got too complex
- ❌ Missing high-level public API (no `ProtoRune.Bsky.post/2`)
- ❌ No rich text builder
- ❌ Bot framework incomplete

**Lexicon Submodule:**
- `priv/atproto/lexicons/` contains official ATProto lexicons as git submodule
- Structure: `app/bsky/feed/post.json`, `com/atproto/repo/createRecord.json`, etc.

---

## Reference Projects Deep Dive

### 1. Jacquard (Rust) - Zero-Copy Performance

**Repository**: `../jacquard/`

**Architecture Highlights:**

```
jacquard/
├── crates/
│   ├── jacquard-api/          # Generated API bindings
│   ├── jacquard-common/        # Foundation types
│   ├── jacquard-lexicon/       # Lexicon parsing & codegen
│   ├── jacquard-identity/      # DID/Handle resolution
│   ├── jacquard-oauth/         # OAuth implementation
│   └── jacquard-derive/        # Proc macros
├── lexicons.kdl                # Lexicon sources config
└── examples/                   # 18 working examples
```

**Key Design Patterns:**

1. **Zero-Copy Deserialization** (from README):
```rust
// Types can borrow from response buffer
let post: Post<'_> = response.parse()?;
// post.text is a CowStr<'_> - no allocation unless needed
```

2. **Lexicon Configuration** (from `lexicons.kdl`):
```kdl
output {
    lexicons "crates/jacquard-api/lexicons"
    codegen "crates/jacquard-api/src"
    cargo-toml "crates/jacquard-api/Cargo.toml"
}

source "bluesky" type="git" priority=101 {
    repo "https://github.com/bluesky-social/atproto"
    pattern "**/*.json"
}

source "leaflet" type="git" priority=100 {
    repo "https://github.com/hyperlink-academy/leaflet"
    pattern "**/*.json"
}
```

3. **Agent Pattern** (from README example):
```rust
// Simple OAuth login + API call
let oauth = OAuthClient::with_default_config(FileAuthStore::new(&args.store));
let session = oauth.login_with_local_server(handle, ...).await?;
let agent: Agent<_> = Agent::from(session);

let timeline = agent
    .send(&GetTimeline::new().limit(5).build())
    .await?
    .into_output()?;
```

**Lessons for ProtoRune:**
- ✅ Modular crate structure → modular Elixir apps
- ✅ Agent pattern for session management
- ✅ Builder pattern for complex types (timeline query)
- ✅ Excellent README with quick start examples

---

### 2. Peri (Elixir) - Flexible Schema Validation

**Repository**: `../peri/`

**Core Architecture** (from `lib/peri.ex`):

```elixir
# Peri's key innovation: schemas are just data
defschema :user, %{
  name: :string,
  age: {:integer, {:gte, 18}},
  email: {:required, :string},
  role: {:enum, [:admin, :user, :guest]},
  # Nested schemas
  address: %{
    street: :string,
    city: {:required, :string}
  },
  # Complex types
  preferences: {:map, :string, :any},
  # Union types (perfect for ATProto!)
  content: {:oneof, [
    %{type: {:literal, "post"}, text: :string},
    %{type: {:literal, "image"}, url: :string}
  ]},
  # Dynamic types based on data
  value: {:dependent, fn current, root ->
    case current.type do
      "number" -> {:ok, :integer}
      "text" -> {:ok, :string}
      _ -> {:ok, :any}
    end
  end}
}

# Usage
{:ok, valid_data} = MySchemas.user(user_data)

# Ecto integration when needed
changeset = MySchemas.user_changeset(user_data)
```

**Key Features for ATProto:**

1. **Union Types** (line 84-85):
```elixir
@type schema_def ::
  :any | :atom | :boolean | :map | :pid |
  {:either, {schema_def, schema_def}} |
  {:oneof, list(schema_def)} |  # Perfect for ATProto unions!
  {:enum, list(term)} |
  {:list, schema_def} |
  {:map, schema_def} |
  {:literal, literal} |
  {:dependent, callback}  # Dynamic type resolution!
```

2. **Permissive Mode** (line 314-319):
```elixir
# Strict mode (default) - only schema fields
Peri.validate(schema, data, mode: :strict)
# => {:ok, %{name: "John", age: 30}}

# Permissive mode - preserves extra fields
Peri.validate(schema, data, mode: :permissive)
# => {:ok, %{name: "John", age: 30, extra: "field"}}
```

3. **Ecto Integration** (line 1417-1436):
```elixir
# Optional Ecto integration
defschema :user, %{
  name: :string,
  email: {:required, :string}
}

# Auto-generated!
def user_changeset(data) do
  Peri.to_changeset!(get_schema(:user), data)
end
```

4. **Transform Support** (line 857-907):
```elixir
# Transform validated data
{:string, {:transform, &String.upcase/1}}
{:string, {:transform, {MyModule, :sanitize}}}
```

**Why Peri is Perfect for ATProto:**
- ✅ Handles `"unknown"` types (`:any`)
- ✅ Union types via `:oneof` (ATProto has many unions)
- ✅ Dynamic types via `:dependent` (conditional schemas)
- ✅ No rigid struct definitions
- ✅ Optional Ecto integration for persistence
- ✅ Custom validation and transforms
- ✅ Detailed error messages with paths

---

### 3. atcute (TypeScript) - Lightweight & Modular

**Key Insights from Web Research:**

**Architecture:**
```typescript
// Modular package structure
@atcute/client          // XRPC client
@atcute/oauth-client    // OAuth flow
@atcute/lexicon         // Schema tools
@atcute/did-resolver    // DID resolution
@mary/bluesky-richtext  // Rich text helpers
```

**API Design Philosophy:**
- Lightweight packages - use only what you need
- Type-safe XRPC calls
- Simple client creation
- Focus on developer experience

**Example Usage Pattern:**
```typescript
import { Client } from '@atcute/client'

const client = new Client()
await client.login({
  identifier: 'handle.bsky.social',
  password: 'app-password'
})

// Type-safe API calls
const timeline = await client.call('app.bsky.feed.getTimeline', {
  limit: 10
})
```

**Lessons:**
- ✅ Simple, explicit client management
- ✅ Modular architecture
- ✅ Developer-friendly defaults
- ✅ Progressive disclosure (simple → complex)

---

## Proposal 1: Lexicon Code Generation

### Why Peri Instead of Ecto?

**Ecto Approach (Your Original Attempt):**
```elixir
# Complex, rigid, database-focused
defmodule Lexicon.App.Bsky.Feed.Post do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :text, :string
    field :created_at, :utc_datetime
    embeds_many :facets, Facet  # Requires Facet to be Ecto schema
    embeds_one :reply, ReplyRef
    # Union types are painful
    # "unknown" types don't work well
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:text, :created_at])
    |> cast_embed(:facets)  # Nested complexity
    |> validate_required([:text, :created_at])
  end
end
```

**Problems:**
- ❌ Ecto expects database persistence
- ❌ Union types require custom Ecto.Type
- ❌ "unknown" type doesn't map to Ecto
- ❌ Embedded schemas everywhere
- ❌ Heavy boilerplate

**Peri Approach (Proposed):**
```elixir
# Flexible, protocol-focused
defmodule ProtoRune.Lexicon.App.Bsky.Feed.Post do
  import Peri

  defschema :main, %{
    text: {:required, {:string, {:max_length, 3000}}},
    created_at: {:required, :datetime},
    facets: {:list, ProtoRune.Lexicon.App.Bsky.Richtext.Facet},
    reply: ProtoRune.Lexicon.App.Bsky.Feed.Post.ReplyRef,
    # Union types are natural!
    embed: {:oneof, [
      ProtoRune.Lexicon.App.Bsky.Embed.Images,
      ProtoRune.Lexicon.App.Bsky.Embed.Video,
      ProtoRune.Lexicon.App.Bsky.Embed.External
    ]},
    langs: {:list, :string},
    labels: ProtoRune.Lexicon.Com.Atproto.Label.Defs.SelfLabels,
    tags: {:list, {:string, {:max_length, 640}}}
  }

  # Validation is just a function call
  def validate(data), do: main(data)

  # Convenience constructor
  def new(text, opts \\ []) do
    %{
      text: text,
      created_at: opts[:created_at] || DateTime.utc_now(),
      facets: opts[:facets] || [],
      reply: opts[:reply],
      embed: opts[:embed],
      langs: opts[:langs] || ["en"],
      labels: opts[:labels],
      tags: opts[:tags] || []
    }
    |> validate()
  end

  # Optional Ecto when needed
  def changeset(data), do: main_changeset(data)
end
```

**Benefits:**
- ✅ Clean, simple code
- ✅ Union types via `:oneof`
- ✅ "unknown" types via `:any`
- ✅ No embedded schema complexity
- ✅ Optional Ecto integration

---

### Implementation Strategy

#### Phase 1: Enhanced Lexicon Loader

**File**: `lib/proto_rune/lexicon/generator.ex`

```elixir
defmodule ProtoRune.Lexicon.Generator do
  @moduledoc """
  Generates Peri schemas from AT Protocol lexicons.

  Transforms lexicon JSON definitions into idiomatic Elixir modules with
  Peri schema validation, following ATProto specifications.
  """

  alias ProtoRune.Lexicon.TypeMapper

  @doc """
  Generates an Elixir module from a lexicon definition.

  ## Example

      lexicon = %{
        id: "app.bsky.feed.post",
        defs: %{
          "main" => %{
            type: "record",
            properties: %{"text" => %{"type" => "string"}},
            required: ["text"]
          }
        }
      }

      Generator.generate_module(lexicon)
      # => AST for ProtoRune.Lexicon.App.Bsky.Feed.Post
  """
  def generate_module(lexicon) do
    module_name = module_name_from_id(lexicon.id)
    schemas = generate_schemas(lexicon.defs)
    helpers = generate_helpers(lexicon)

    quote do
      defmodule unquote(module_name) do
        @moduledoc unquote(generate_moduledoc(lexicon))

        import Peri

        unquote_splicing(schemas)
        unquote_splicing(helpers)
      end
    end
  end

  defp generate_schemas(defs) do
    Enum.map(defs, fn {name, def} ->
      schema_name = String.to_atom(name)

      case def.type do
        "record" -> generate_record_schema(schema_name, def)
        "query" -> generate_query_schema(schema_name, def)
        "procedure" -> generate_procedure_schema(schema_name, def)
        "object" -> generate_object_schema(schema_name, def)
        "token" -> generate_token_schema(schema_name, def)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_record_schema(name, def) do
    properties = def[:properties] || def["record"]["properties"] || %{}
    required = def[:required] || def["record"]["required"] || []

    schema_map =
      properties
      |> Enum.map(fn {key, prop_def} ->
        type = TypeMapper.map_to_peri(prop_def)
        key_atom = String.to_atom(key)

        value = if key in required do
          {:required, type}
        else
          type
        end

        {key_atom, value}
      end)
      |> Map.new()

    quote do
      defschema unquote(name), unquote(Macro.escape(schema_map))
    end
  end

  defp generate_object_schema(name, def) do
    # Similar to record but for nested objects
    generate_record_schema(name, def)
  end

  defp generate_query_schema(name, def) do
    # Generate schemas for query parameters and output
    params_schema = generate_params_schema(def["parameters"])
    output_schema = generate_output_schema(def["output"])

    [params_schema, output_schema]
  end

  defp generate_procedure_schema(name, def) do
    # Generate schemas for input/output
    input_schema = generate_input_schema(def["input"])
    output_schema = generate_output_schema(def["output"])

    [input_schema, output_schema]
  end

  defp generate_token_schema(name, _def) do
    # Tokens are just atoms/strings
    quote do
      def unquote(name)(value) when is_binary(value) or is_atom(value) do
        {:ok, value}
      end
    end
  end

  defp generate_helpers(lexicon) do
    main_def = lexicon.defs["main"]

    case main_def && main_def.type do
      "record" -> generate_record_helpers(lexicon)
      _ -> []
    end
  end

  defp generate_record_helpers(_lexicon) do
    [
      quote do
        @doc """
        Validates data against the main schema.
        """
        def validate(data), do: main(data)

        @doc """
        Validates data against the main schema, raising on error.
        """
        def validate!(data), do: main!(data)
      end
    ]
  end

  defp module_name_from_id(id) do
    # "app.bsky.feed.post" => ProtoRune.Lexicon.App.Bsky.Feed.Post
    parts =
      id
      |> String.split(".")
      |> Enum.map(&Macro.camelize/1)

    Module.concat([ProtoRune, Lexicon | parts])
  end

  defp generate_moduledoc(lexicon) do
    description = lexicon[:description] || "Generated from lexicon: #{lexicon.id}"

    """
    #{description}

    **Lexicon ID**: `#{lexicon.id}`

    This module was auto-generated from the AT Protocol lexicon definition.
    """
  end
end
```

#### Phase 2: Type Mapper

**File**: `lib/proto_rune/lexicon/type_mapper.ex`

```elixir
defmodule ProtoRune.Lexicon.TypeMapper do
  @moduledoc """
  Maps AT Protocol lexicon types to Peri schema types.
  """

  @doc """
  Maps a lexicon type definition to a Peri schema type.

  ## Examples

      # String with max length
      map_to_peri(%{"type" => "string", "maxLength" => 100})
      # => {:string, {:max, 100}}

      # Integer with range
      map_to_peri(%{"type" => "integer", "minimum" => 0, "maximum" => 100})
      # => {:integer, [{:gte, 0}, {:lte, 100}]}

      # Reference to another schema
      map_to_peri(%{"type" => "ref", "ref" => "app.bsky.richtext.facet"})
      # => ProtoRune.Lexicon.App.Bsky.Richtext.Facet

      # Union type
      map_to_peri(%{"type" => "union", "refs" => ["com.atproto.label.defs#selfLabels"]})
      # => {:oneof, [ProtoRune.Lexicon.Com.Atproto.Label.Defs.SelfLabels]}

      # Array
      map_to_peri(%{"type" => "array", "items" => %{"type" => "string"}})
      # => {:list, :string}
  """
  def map_to_peri(type_def) when is_map(type_def) do
    case type_def["type"] || type_def[:type] do
      "string" -> map_string_type(type_def)
      "integer" -> map_integer_type(type_def)
      "number" -> map_number_type(type_def)
      "boolean" -> :boolean
      "blob" -> :binary
      "bytes" -> :binary
      "cid-link" -> :string  # CID as string
      "datetime" -> :datetime
      "ref" -> map_ref_type(type_def)
      "union" -> map_union_type(type_def)
      "array" -> map_array_type(type_def)
      "object" -> map_object_type(type_def)
      "unknown" -> :any  # Peri's flexible type
      nil -> :any
      other -> raise "Unknown lexicon type: #{other}"
    end
  end

  defp map_string_type(def) do
    constraints = []

    constraints = if max = def["maxLength"] do
      [{:max, max} | constraints]
    else
      constraints
    end

    constraints = if min = def["minLength"] do
      [{:min, min} | constraints]
    else
      constraints
    end

    constraints = if format = def["format"] do
      # ATProto formats: at-uri, at-identifier, nsid, cid, datetime, etc
      case format do
        "uri" -> [{:regex, ~r/^https?:\/\//} | constraints]
        "at-uri" -> [{:regex, ~r/^at:\/\//} | constraints]
        "datetime" -> [:datetime]  # Use Peri's datetime type instead
        _ -> constraints
      end
    else
      constraints
    end

    case constraints do
      [] -> :string
      [single] -> {:string, single}
      multiple -> {:string, multiple}
    end
  end

  defp map_integer_type(def) do
    constraints = []

    constraints = if max = def["maximum"] do
      [{:lte, max} | constraints]
    else
      constraints
    end

    constraints = if min = def["minimum"] do
      [{:gte, min} | constraints]
    else
      constraints
    end

    case constraints do
      [] -> :integer
      [single] -> {:integer, single}
      multiple -> {:integer, multiple}
    end
  end

  defp map_number_type(def) do
    # Similar to integer but for floats
    constraints = []

    constraints = if max = def["maximum"] do
      [{:lte, max} | constraints]
    else
      constraints
    end

    constraints = if min = def["minimum"] do
      [{:gte, min} | constraints]
    else
      constraints
    end

    case constraints do
      [] -> :float
      [single] -> {:float, single}
      multiple -> {:float, multiple}
    end
  end

  defp map_ref_type(%{"ref" => ref}) when is_binary(ref) do
    # Convert "app.bsky.richtext.facet" to ProtoRune.Lexicon.App.Bsky.Richtext.Facet
    # Handle fragments: "app.bsky.feed.post#replyRef" => App.Bsky.Feed.Post.ReplyRef
    [nsid, fragment] = case String.split(ref, "#") do
      [nsid] -> [nsid, nil]
      [nsid, frag] -> [nsid, frag]
    end

    parts =
      nsid
      |> String.split(".")
      |> Enum.map(&Macro.camelize/1)

    parts = if fragment do
      parts ++ [Macro.camelize(fragment)]
    else
      parts
    end

    Module.concat([ProtoRune, Lexicon | parts])
  end

  defp map_union_type(%{"refs" => refs}) when is_list(refs) do
    types = Enum.map(refs, fn ref ->
      map_ref_type(%{"ref" => ref})
    end)

    {:oneof, types}
  end

  defp map_array_type(%{"items" => items}) do
    item_type = map_to_peri(items)
    {:list, item_type}
  end

  defp map_object_type(def) do
    # Nested object - generate inline schema
    properties = def["properties"] || %{}
    required = def["required"] || []

    schema =
      properties
      |> Enum.map(fn {key, prop_def} ->
        type = map_to_peri(prop_def)
        key_atom = String.to_atom(key)

        value = if key in required do
          {:required, type}
        else
          type
        end

        {key_atom, value}
      end)
      |> Map.new()

    schema
  end
end
```

#### Phase 3: Mix Task

**File**: `lib/mix/tasks/proto_rune/gen/lexicons.ex`

```elixir
defmodule Mix.Tasks.ProtoRune.Gen.Lexicons do
  use Mix.Task

  @shortdoc "Generates Elixir modules from AT Protocol lexicons"

  @moduledoc """
  Generates Peri schema modules from AT Protocol lexicon definitions.

  ## Usage

      mix proto_rune.gen.lexicons

  This task will:
  1. Load all lexicons from priv/atproto/lexicons/
  2. Build dependency graph
  3. Generate modules in topological order
  4. Write to lib/proto_rune/lexicon/generated/

  ## Options

      --clean    Remove generated directory before generation
      --force    Overwrite existing files
  """

  alias ProtoRune.Lexicon.{Loader, Generator, DependencyGraph}

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [clean: :boolean, force: :boolean]
    )

    lexicons_dir = Path.join("priv", "atproto/lexicons")
    output_dir = Path.join("lib", "proto_rune/lexicon/generated")

    if opts[:clean] do
      Mix.shell().info("Cleaning #{output_dir}...")
      File.rm_rf!(output_dir)
    end

    Mix.shell().info("Loading lexicons from #{lexicons_dir}...")

    with {:ok, {lexicons, graph}} <- load_all_lexicons(lexicons_dir),
         sorted <- DependencyGraph.topological_sort(graph) do

      Mix.shell().info("Found #{length(lexicons)} lexicons")
      Mix.shell().info("Generating modules...")

      results =
        sorted
        |> Enum.map(fn lexicon_id ->
          lexicon = Enum.find(lexicons, &(&1.id == lexicon_id))
          generate_and_write(lexicon, output_dir, opts)
        end)

      successful = Enum.count(results, &match?({:ok, _}, &1))
      failed = Enum.count(results, &match?({:error, _}, &1))

      Mix.shell().info("")
      Mix.shell().info("✓ Generated #{successful} modules")

      if failed > 0 do
        Mix.shell().error("✗ Failed to generate #{failed} modules")
      end
    else
      {:error, reason} ->
        Mix.shell().error("Failed to load lexicons: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp load_all_lexicons(dir) do
    # Recursively find all .json files
    files =
      Path.wildcard(Path.join(dir, "**/*.json"))
      |> Enum.sort()

    Mix.shell().info("Found #{length(files)} lexicon files")

    Loader.load_from_files(files)
  end

  defp generate_and_write(lexicon, output_dir, opts) do
    try do
      # Generate module AST
      ast = Generator.generate_module(lexicon)

      # Convert to formatted source code
      code =
        ast
        |> Macro.to_string()
        |> Code.format_string!()
        |> IO.iodata_to_binary()

      # Determine output file path
      file_path = module_file_path(lexicon.id, output_dir)

      # Check if file exists and force flag
      if File.exists?(file_path) and not opts[:force] do
        Mix.shell().info("  ⊙ #{lexicon.id} (skipped, already exists)")
        {:ok, :skipped}
      else
        # Create directory if needed
        File.mkdir_p!(Path.dirname(file_path))

        # Write file
        File.write!(file_path, code)

        Mix.shell().info("  ✓ #{lexicon.id}")
        {:ok, file_path}
      end
    rescue
      error ->
        Mix.shell().error("  ✗ #{lexicon.id}: #{Exception.message(error)}")
        {:error, error}
    end
  end

  defp module_file_path(lexicon_id, output_dir) do
    # "app.bsky.feed.post" => "app/bsky/feed/post.ex"
    path =
      lexicon_id
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    Path.join(output_dir, "#{path}.ex")
  end
end
```

#### Phase 4: Compile-Time Hook

**File**: `mix.exs`

```elixir
defmodule ProtoRune.MixProject do
  use Mix.Project

  def project do
    [
      # ...
      compilers: compilers(Mix.env()),
      # ...
    ]
  end

  defp compilers(:test), do: Mix.compilers()
  defp compilers(_), do: [:proto_rune_lexicons] ++ Mix.compilers()
end

defmodule Mix.Tasks.Compile.ProtoRuneLexicons do
  use Mix.Task.Compiler

  @recursive true
  @manifest "compile.proto_rune_lexicons"

  def run(_args) do
    # Check if lexicons have changed
    lexicons_dir = Path.join("priv", "atproto/lexicons")
    output_dir = Path.join("lib", "proto_rune/lexicon/generated")

    if should_regenerate?(lexicons_dir, output_dir) do
      Mix.Task.run("proto_rune.gen.lexicons", [])
      {:ok, []}
    else
      {:noop, []}
    end
  end

  defp should_regenerate?(lexicons_dir, output_dir) do
    # Simple check: if output dir doesn't exist, regenerate
    not File.exists?(output_dir) or
      # Or if any lexicon file is newer than any generated file
      lexicons_newer?(lexicons_dir, output_dir)
  end

  defp lexicons_newer?(lexicons_dir, output_dir) do
    lexicon_mtime = newest_file_time(Path.join(lexicons_dir, "**/*.json"))
    generated_mtime = newest_file_time(Path.join(output_dir, "**/*.ex"))

    lexicon_mtime > generated_mtime
  end

  defp newest_file_time(pattern) do
    pattern
    |> Path.wildcard()
    |> Enum.map(fn file ->
      case File.stat(file) do
        {:ok, %{mtime: mtime}} -> mtime
        _ -> {{1970, 1, 1}, {0, 0, 0}}
      end
    end)
    |> Enum.max(fn -> {{1970, 1, 1}, {0, 0, 0}} end)
  end
end
```

---

### Generated Code Example

**Input**: `priv/atproto/lexicons/app/bsky/feed/post.json`

**Output**: `lib/proto_rune/lexicon/generated/app/bsky/feed/post.ex`

```elixir
defmodule ProtoRune.Lexicon.App.Bsky.Feed.Post do
  @moduledoc """
  Record containing a Bluesky post.

  **Lexicon ID**: `app.bsky.feed.post`

  This module was auto-generated from the AT Protocol lexicon definition.
  """

  import Peri

  defschema :main, %{
    text: {:required, {:string, {:max, 3000}}},
    entities: {:list, ProtoRune.Lexicon.App.Bsky.Feed.Post.Entity},
    facets: {:list, ProtoRune.Lexicon.App.Bsky.Richtext.Facet},
    reply: ProtoRune.Lexicon.App.Bsky.Feed.Post.ReplyRef,
    embed: {:oneof, [
      ProtoRune.Lexicon.App.Bsky.Embed.Images,
      ProtoRune.Lexicon.App.Bsky.Embed.Video,
      ProtoRune.Lexicon.App.Bsky.Embed.External,
      ProtoRune.Lexicon.App.Bsky.Embed.Record,
      ProtoRune.Lexicon.App.Bsky.Embed.RecordWithMedia
    ]},
    langs: {:list, :string},
    labels: ProtoRune.Lexicon.Com.Atproto.Label.Defs.SelfLabels,
    tags: {:list, {:string, {:max, 640}}},
    created_at: {:required, :datetime}
  }

  defschema :reply_ref, %{
    root: {:required, ProtoRune.Lexicon.Com.Atproto.Repo.StrongRef},
    parent: {:required, ProtoRune.Lexicon.Com.Atproto.Repo.StrongRef}
  }

  defschema :entity, %{
    index: {:required, ProtoRune.Lexicon.App.Bsky.Feed.Post.TextSlice},
    type: {:required, :string},
    value: {:required, :string}
  }

  defschema :text_slice, %{
    start: {:required, {:integer, {:gte, 0}}},
    end: {:required, {:integer, {:gte, 0}}}
  }

  @doc """
  Validates data against the main schema.
  """
  def validate(data), do: main(data)

  @doc """
  Validates data against the main schema, raising on error.
  """
  def validate!(data), do: main!(data)
end
```

**Usage:**

```elixir
alias ProtoRune.Lexicon.App.Bsky.Feed.Post

# Validate a post
post_data = %{
  text: "Hello Bluesky!",
  created_at: DateTime.utc_now(),
  langs: ["en"]
}

{:ok, valid_post} = Post.validate(post_data)
# => {:ok, %{text: "Hello Bluesky!", created_at: ~U[...], langs: ["en"]}}

# Invalid data
{:error, errors} = Post.validate(%{created_at: DateTime.utc_now()})
# => {:error, [text: "is required, expected type of :string"]}

# Use with Ecto if needed
changeset = Post.main_changeset(post_data)
```

---

## Proposal 2: Public API Design

### Inspiration: atcute + jacquard

**Design Principles:**
1. **Progressive Disclosure**: Simple tasks simple, complex tasks possible
2. **Layered API**: High-level → Mid-level → Low-level
3. **Explicit Sessions**: Functional style, pass session explicitly
4. **Builder Patterns**: For complex constructions (rich text, queries)
5. **Type Safety**: Leverage generated schemas

### Module Organization

```
lib/
├── proto_rune.ex                    # Main API + client creation
├── proto_rune/
│   ├── client.ex                    # Client struct and basics
│   ├── session.ex                   # Session management
│   ├── rich_text.ex                 # Rich text builder
│   └── xrpc.ex                      # Low-level XRPC
├── atproto/
│   ├── identity.ex                  # DID/handle resolution
│   ├── repo.ex                      # Repository CRUD
│   ├── sync.ex                      # Sync operations
│   └── server.ex                    # Server methods
├── bsky/                            # High-level Bluesky API
│   ├── actor.ex                     # Profile operations
│   ├── feed.ex                      # Post/timeline/feed ops
│   ├── graph.ex                     # Follow/block/mute ops
│   ├── notification.ex              # Notification ops
│   └── chat.ex                      # Chat operations
├── bot/
│   ├── bot.ex                       # Bot behavior
│   ├── poller.ex                    # Polling strategy
│   └── firehose.ex                  # Firehose strategy
└── oauth/
    ├── client.ex                    # OAuth client
    └── server.ex                    # OAuth server helpers
```

### API Examples

#### 1. Client Creation & Auth

```elixir
# Simple client
{:ok, client} = ProtoRune.new("https://bsky.social")

# With options
{:ok, client} = ProtoRune.new("https://bsky.social",
  timeout: 30_000,
  user_agent: "MyApp/1.0"
)

# Login with password
{:ok, session} = ProtoRune.login(client, "handle.bsky.social", "app-password")

# OAuth (future)
{:ok, session} = ProtoRune.OAuth.login(client, "handle.bsky.social",
  redirect_uri: "http://localhost:3000/callback"
)

# Resume session
{:ok, session} = ProtoRune.resume_session(client, access_jwt, refresh_jwt)
```

#### 2. High-Level Bluesky API

```elixir
alias ProtoRune.Bsky

# Simple post
{:ok, post} = Bsky.post(session, "Hello from Elixir! 🚀")

# Post with options
{:ok, post} = Bsky.post(session, "Check this out!",
  langs: ["en"],
  labels: ["spam"],
  reply_to: "at://did:plc:xyz/app.bsky.feed.post/123"
)

# Get timeline
{:ok, timeline} = Bsky.get_timeline(session, limit: 20, cursor: nil)

# Get profile
{:ok, profile} = Bsky.get_profile(session, "alice.bsky.social")

# Follow
{:ok, follow} = Bsky.follow(session, "alice.bsky.social")

# Like
{:ok, like} = Bsky.like(session, post.uri, post.cid)

# Repost
{:ok, repost} = Bsky.repost(session, post.uri, post.cid)

# Delete post
:ok = Bsky.delete_post(session, post.uri)
```

#### 3. Rich Text Builder

```elixir
alias ProtoRune.RichText

# Simple usage
{:ok, rt} =
  RichText.new()
  |> RichText.text("Hello ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text("! Check out ")
  |> RichText.link("this project", "https://example.com")
  |> RichText.text(" ")
  |> RichText.hashtag("elixir")
  |> RichText.build()

# Use in post
{:ok, post} = Bsky.post(session, rt)

# Parse from markdown-like syntax (future)
{:ok, rt} = RichText.parse("""
Hello @alice.bsky.social! Check out [this project](https://example.com) #elixir
""")

# Get plain text
plain = RichText.to_plain_text(rt)
# => "Hello @alice.bsky.social! Check out this project #elixir"
```

**Implementation**: `lib/proto_rune/rich_text.ex`

```elixir
defmodule ProtoRune.RichText do
  @moduledoc """
  Builder for AT Protocol rich text with facets.

  Handles byte offset calculation and facet generation.
  """

  alias ProtoRune.Lexicon.App.Bsky.Richtext.Facet

  defstruct text: "", facets: []

  @type t :: %__MODULE__{
    text: String.t(),
    facets: [map()]
  }

  @doc "Creates a new rich text builder"
  def new, do: %__MODULE__{}

  @doc "Appends plain text"
  def text(%__MODULE__{} = rt, content) when is_binary(content) do
    %{rt | text: rt.text <> content}
  end

  @doc "Appends a mention"
  def mention(%__MODULE__{} = rt, handle) when is_binary(handle) do
    # Calculate byte offsets
    byte_start = byte_size(rt.text)
    mention_text = "@#{handle}"
    byte_end = byte_start + byte_size(mention_text)

    facet = %{
      index: %{
        byteStart: byte_start,
        byteEnd: byte_end
      },
      features: [
        %{
          "$type" => "app.bsky.richtext.facet#mention",
          did: handle  # TODO: resolve to DID
        }
      ]
    }

    %{rt |
      text: rt.text <> mention_text,
      facets: rt.facets ++ [facet]
    }
  end

  @doc "Appends a link"
  def link(%__MODULE__{} = rt, link_text, url) do
    byte_start = byte_size(rt.text)
    byte_end = byte_start + byte_size(link_text)

    facet = %{
      index: %{
        byteStart: byte_start,
        byteEnd: byte_end
      },
      features: [
        %{
          "$type" => "app.bsky.richtext.facet#link",
          uri: url
        }
      ]
    }

    %{rt |
      text: rt.text <> link_text,
      facets: rt.facets ++ [facet]
    }
  end

  @doc "Appends a hashtag"
  def hashtag(%__MODULE__{} = rt, tag) do
    byte_start = byte_size(rt.text)
    tag_text = "##{tag}"
    byte_end = byte_start + byte_size(tag_text)

    facet = %{
      index: %{
        byteStart: byte_start,
        byteEnd: byte_end
      },
      features: [
        %{
          "$type" => "app.bsky.richtext.facet#tag",
          tag: tag
        }
      ]
    }

    %{rt |
      text: rt.text <> tag_text,
      facets: rt.facets ++ [facet]
    }
  end

  @doc "Builds and validates the rich text"
  def build(%__MODULE__{} = rt) do
    # Validate with generated schema
    post_data = %{
      text: rt.text,
      facets: rt.facets
    }

    # Return as map suitable for post
    {:ok, post_data}
  end

  @doc "Converts rich text back to plain text"
  def to_plain_text(%__MODULE__{text: text}), do: text
  def to_plain_text(%{text: text}), do: text
end
```

#### 4. Mid-Level XRPC

```elixir
alias ProtoRune.XRPC

# Generic XRPC call
{:ok, response} = XRPC.call(session, :get, "app.bsky.feed.getTimeline", %{
  limit: 10,
  cursor: nil
})

# With generated schemas
alias ProtoRune.Lexicon.App.Bsky.Feed.GetTimeline

params = GetTimeline.Params.new(limit: 10)
{:ok, timeline} = XRPC.call(session, :get, "app.bsky.feed.getTimeline", params)
```

#### 5. Low-Level Repository Operations

```elixir
alias ProtoRune.ATProto.Repo

# Create record
{:ok, record} = Repo.create_record(session,
  collection: "app.bsky.feed.post",
  record: %{
    "$type" => "app.bsky.feed.post",
    "text" => "Hello!",
    "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
  }
)

# Get record
{:ok, record} = Repo.get_record(session,
  did: session.did,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
)

# Update record
{:ok, updated} = Repo.put_record(session,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz...",
  record: updated_post
)

# Delete record
:ok = Repo.delete_record(session,
  collection: "app.bsky.feed.post",
  rkey: "3kxyz..."
)

# List records
{:ok, records} = Repo.list_records(session,
  collection: "app.bsky.feed.post",
  limit: 50
)
```

#### 6. Bot Framework

```elixir
defmodule GreeterBot do
  use ProtoRune.Bot,
    handle: "greeter.bsky.social",
    password: System.get_env("BOT_PASSWORD"),
    strategy: :polling,      # or :firehose
    interval: 30_000         # polling interval

  # Handle mentions
  @impl true
  def handle_event({:mention, notification}, state) do
    # Get the post that mentioned us
    {:ok, thread} = ProtoRune.Bsky.get_post_thread(
      state.session,
      notification.uri
    )

    post = thread.post

    # Reply
    {:ok, _reply} = ProtoRune.Bsky.post(
      state.session,
      "👋 Hi #{post.author.handle}! Thanks for the mention!",
      reply_to: post.uri
    )

    {:ok, state}
  end

  # Handle likes
  @impl true
  def handle_event({:like, notification}, state) do
    Logger.info("Got a like from #{notification.author.handle}")
    {:ok, state}
  end

  # Handle follows
  @impl true
  def handle_event({:follow, notification}, state) do
    # Follow back
    {:ok, _} = ProtoRune.Bsky.follow(state.session, notification.author.did)
    {:ok, state}
  end

  # Catch-all
  @impl true
  def handle_event(_event, state) do
    {:ok, state}
  end
end

# Start the bot
{:ok, pid} = GreeterBot.start_link()

# Or in supervision tree
children = [
  {GreeterBot, []}
]
```

**Implementation**: `lib/proto_rune/bot/bot.ex`

```elixir
defmodule ProtoRune.Bot do
  @moduledoc """
  Behavior for creating bots that respond to events.

  ## Example

      defmodule MyBot do
        use ProtoRune.Bot,
          handle: "mybot.bsky.social",
          password: System.get_env("BOT_PASSWORD"),
          strategy: :polling,
          interval: 30_000

        @impl true
        def handle_event({:mention, notification}, state) do
          # Handle mention
          {:ok, state}
        end
      end
  """

  @callback handle_event(event :: term(), state :: map()) ::
    {:ok, new_state :: map()} |
    {:error, reason :: term()}

  defmacro __using__(opts) do
    quote do
      use GenServer

      @behaviour ProtoRune.Bot

      def start_link(init_args \\ []) do
        GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
      end

      @impl GenServer
      def init(_init_args) do
        opts = unquote(opts)

        # Login
        {:ok, client} = ProtoRune.new(opts[:pds] || "https://bsky.social")
        {:ok, session} = ProtoRune.login(
          client,
          opts[:handle],
          opts[:password]
        )

        state = %{
          client: client,
          session: session,
          strategy: opts[:strategy] || :polling,
          interval: opts[:interval] || 60_000,
          last_seen: nil
        }

        # Start event loop
        schedule_fetch(state)

        {:ok, state}
      end

      @impl GenServer
      def handle_info(:fetch_events, state) do
        case fetch_and_process_events(state) do
          {:ok, new_state} ->
            schedule_fetch(new_state)
            {:noreply, new_state}

          {:error, reason} ->
            # Log error and retry
            require Logger
            Logger.error("Error fetching events: #{inspect(reason)}")
            schedule_fetch(state)
            {:noreply, state}
        end
      end

      defp fetch_and_process_events(state) do
        # Fetch new notifications
        {:ok, notifications} = ProtoRune.Bsky.list_notifications(
          state.session,
          limit: 50,
          seen_at: state.last_seen
        )

        # Process each notification
        new_state = Enum.reduce(notifications.notifications, state, fn notif, acc ->
          event = notification_to_event(notif)

          case handle_event(event, acc) do
            {:ok, new_state} -> new_state
            {:error, _reason} -> acc
          end
        end)

        # Update last_seen
        last_seen = notifications.notifications
          |> List.first()
          |> case do
            nil -> new_state.last_seen
            notif -> notif.indexed_at
          end

        {:ok, %{new_state | last_seen: last_seen}}
      end

      defp notification_to_event(%{reason: "mention"} = notif) do
        {:mention, notif}
      end

      defp notification_to_event(%{reason: "like"} = notif) do
        {:like, notif}
      end

      defp notification_to_event(%{reason: "repost"} = notif) do
        {:repost, notif}
      end

      defp notification_to_event(%{reason: "follow"} = notif) do
        {:follow, notif}
      end

      defp notification_to_event(notif) do
        {:unknown, notif}
      end

      defp schedule_fetch(state) do
        Process.send_after(self(), :fetch_events, state.interval)
      end
    end
  end
end
```

---

## Proposal 3: README & Documentation

### New README.md

Based on jacquard's excellent structure:

```markdown
# ProtoRune

[![Hex.pm](https://img.shields.io/hexpm/v/proto_rune.svg)](https://hex.pm/packages/proto_rune)
[![Documentation](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/proto_rune)

A lightweight, type-safe AT Protocol SDK and bot framework for Elixir, leveraging OTP's strengths for concurrent and real-time applications.

> **Status**: Active development. v0.2.0 will be the first production-ready release.

## Why ProtoRune?

ProtoRune is designed to make ATProto development **simple and elegant**:

- 🎯 **Type-Safe**: Generated schemas from official ATProto lexicons with runtime validation
- 🪶 **Lightweight**: Modular design - use only what you need
- ⚡ **OTP-Native**: Built on GenServers and Supervisors for reliability
- 🎨 **Developer-Friendly**: Intuitive API inspired by atcute and jacquard
- 🔧 **Flexible**: High-level helpers for common tasks, low-level access for everything else

## Quick Start

### Installation

Add to `mix.exs`:

```elixir
def deps do
  [
    {:proto_rune, "~> 0.2.0"}
  ]
end
```

### Your First Post

```elixir
# Create a client and login
{:ok, client} = ProtoRune.new("https://bsky.social")
{:ok, session} = ProtoRune.login(client, "myhandle.bsky.social", "my-app-password")

# Post something
{:ok, post} = ProtoRune.Bsky.post(session, "Hello from Elixir! 🚀")
```

### Rich Text

```elixir
alias ProtoRune.RichText

{:ok, post} =
  RichText.new()
  |> RichText.text("Check out ")
  |> RichText.mention("alice.bsky.social")
  |> RichText.text("'s awesome ")
  |> RichText.link("project", "https://example.com")
  |> RichText.text("! ")
  |> RichText.hashtag("elixir")
  |> RichText.build()
  |> then(&ProtoRune.Bsky.post(session, &1))
```

### Simple Bot

```elixir
defmodule GreeterBot do
  use ProtoRune.Bot,
    handle: "greeter.bsky.social",
    password: System.get_env("BOT_PASSWORD"),
    strategy: :polling,
    interval: 30_000

  @impl true
  def handle_event({:mention, notification}, state) do
    ProtoRune.Bsky.post(
      state.session,
      "👋 Hi #{notification.author.handle}!",
      reply_to: notification.uri
    )
    {:ok, state}
  end
end

# Start the bot
{:ok, _pid} = GreeterBot.start_link()
```

## Features

### High-Level API

- ✅ **Bluesky Operations**: Post, like, repost, follow, block, etc.
- ✅ **Rich Text Builder**: Mentions, links, hashtags with automatic facet generation
- ✅ **Thread Management**: Reply to posts, fetch threads
- ✅ **Notifications**: Subscribe to mentions, likes, follows
- ⏳ **Feed Generators**: Build custom feeds *(coming soon)*

### Low-Level API

- ✅ **XRPC Client**: Direct access to any ATProto endpoint
- ✅ **Repository Operations**: Create, update, delete records
- ✅ **Identity Resolution**: Resolve DIDs and handles
- ⏳ **OAuth Support**: Full OAuth implementation *(coming soon)*

### Bot Framework

- ✅ **Multiple Strategies**: Polling, Firehose *(coming soon)*, Jetstream *(coming soon)*
- ✅ **Event Handling**: Declarative event handlers
- ✅ **Supervision**: Built-in crash recovery via OTP
- ✅ **Rate Limiting**: Automatic backoff and retry

### Code Generation

- ✅ **Lexicon Schemas**: Auto-generated from official ATProto lexicons
- ✅ **Type Validation**: Runtime validation with Peri
- ✅ **Dependency Resolution**: Handles cross-references between lexicons
- ✅ **Compile-Time Generation**: Generated once, cached for performance

## Examples

Browse the [examples/](./examples/) directory:

- [simple_post.ex](./examples/simple_post.ex) - Basic posting
- [rich_text_post.ex](./examples/rich_text_post.ex) - Rich text with mentions and links
- [reply_bot.ex](./examples/reply_bot.ex) - Bot that replies to mentions
- [firehose_filter.ex](./examples/firehose_filter.ex) - Filter firehose events *(coming soon)*
- [feed_generator.ex](./examples/feed_generator.ex) - Custom feed algorithm *(coming soon)*

## Architecture

ProtoRune is organized by ATProto's domain layers:

```
lib/
├── proto_rune.ex          # Main API
├── bsky/                  # Bluesky-specific (feed, graph, etc)
├── atproto/               # Core protocol (identity, repo, sync)
├── bot/                   # Bot framework
├── oauth/                 # OAuth client/server
└── lexicon/generated/     # Auto-generated schemas
```

**Module Guide:**
- `ProtoRune.Bsky.*` - High-level Bluesky operations
- `ProtoRune.ATProto.*` - Low-level protocol operations
- `ProtoRune.Bot` - Bot behavior for event-driven apps
- `ProtoRune.OAuth.*` - OAuth authentication
- `ProtoRune.Lexicon.*` - Generated schemas from lexicons

## Documentation

Full documentation is available at [hexdocs.pm/proto_rune](https://hexdocs.pm/proto_rune).

**Guides:**
- [Getting Started](https://hexdocs.pm/proto_rune/getting_started.html)
- [Authentication](https://hexdocs.pm/proto_rune/authentication.html)
- [Rich Text](https://hexdocs.pm/proto_rune/rich_text.html)
- [Bot Development](https://hexdocs.pm/proto_rune/bots.html)
- [Repository Operations](https://hexdocs.pm/proto_rune/repositories.html) *(Advanced)*
- [Code Generation](https://hexdocs.pm/proto_rune/code_generation.html) *(Advanced)*

## Comparison with Other Libraries

| Feature | ProtoRune | atproto (Python) | atcute (TS) | jacquard (Rust) |
|---------|-----------|------------------|-------------|-----------------|
| Language | Elixir | Python | TypeScript | Rust |
| Type Safety | ✅ Runtime | ⚠️ Optional | ✅ Compile | ✅ Compile |
| Bot Framework | ✅ OTP-based | ❌ | ❌ | ❌ |
| Code Gen | ✅ Peri schemas | ⚠️ Limited | ✅ | ✅ |
| Performance | ⚡ BEAM VM | 🐌 | 🚀 | 🚀🚀 |
| Concurrency | ✅ Actor model | ⚠️ asyncio | ⚠️ Promise | ⚠️ Tokio |
| Hot Reload | ✅ | ❌ | ❌ | ❌ |

**When to use ProtoRune:**
- Building Bluesky bots that need reliability
- Applications requiring hot code reloading
- Services with high concurrency needs
- Teams already using Elixir/Phoenix

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development setup and guidelines.

**Development Setup:**

```bash
# Clone with submodules (for lexicons)
git clone --recurse-submodules https://github.com/zoedsoupe/proto_rune.git
cd proto_rune

# Install dependencies
mix deps.get

# Generate lexicon schemas
mix proto_rune.gen.lexicons

# Run tests
mix test

# Start IEx with ProtoRune loaded
iex -S mix
```

## Inspirations

ProtoRune stands on the shoulders of giants:

- **[atcute](https://github.com/mary-ext/atcute)** - Lightweight TypeScript ATProto library
- **[jacquard](https://github.com/nonbinary-computer/jacquard)** - High-performance Rust ATProto library
- **[Peri](https://github.com/zoedsoupe/peri)** - Flexible Elixir schema validation
- **[skyware](https://skyware.js.org/)** - JavaScript bot framework

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Community

- **Discord**: [Join our community](https://discord.gg/proto-rune) *(coming soon)*
- **Forum**: [Discuss on GitHub Discussions](https://github.com/zoedsoupe/proto_rune/discussions)
- **Blog**: [Read about ProtoRune](https://zoedsoupe.dev/blog/proto-rune)

---

**Built with ❤️ by [@zoedsoupe](https://github.com/zoedsoupe) and contributors**
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Core infrastructure and code generation

**Tasks:**
- [ ] Enhanced `ProtoRune.Lexicon.Loader`
  - [x] Basic loading (already done)
  - [ ] Dependency graph improvements
  - [ ] Fragment resolution (`#replyRef`)
- [ ] `ProtoRune.Lexicon.TypeMapper`
  - [ ] All basic types
  - [ ] Union types (`:oneof`)
  - [ ] References (`:ref`)
  - [ ] Nested objects
- [ ] `ProtoRune.Lexicon.Generator`
  - [ ] Record schemas
  - [ ] Query/procedure schemas
  - [ ] Helper functions
  - [ ] Moduledoc generation
- [ ] Mix task `proto_rune.gen.lexicons`
  - [ ] Basic generation
  - [ ] Progress reporting
  - [ ] Error handling
- [ ] Compile-time hook
  - [ ] Detect lexicon changes
  - [ ] Auto-regenerate

**Deliverable**: `mix proto_rune.gen.lexicons` generates all Peri schemas from lexicons

---

### Phase 2: Core API (Weeks 3-4)

**Goal**: Client, session, and basic operations

**Tasks:**
- [ ] `ProtoRune` main module
  - [ ] `new/2` - client creation
  - [ ] `login/3` - password auth
  - [ ] `resume_session/3` - session resume
- [ ] `ProtoRune.Client`
  - [ ] HTTP client wrapper (Req)
  - [ ] Base URL management
  - [ ] User agent
- [ ] `ProtoRune.Session`
  - [ ] Session struct
  - [ ] Token refresh
  - [ ] Session validation
- [ ] `ProtoRune.XRPC`
  - [ ] GET/POST/DELETE methods
  - [ ] Query params
  - [ ] Request bodies
  - [ ] Response parsing
  - [ ] Error handling
- [ ] `ProtoRune.ATProto.Identity`
  - [ ] Handle resolution
  - [ ] DID resolution
  - [ ] Caching
- [ ] `ProtoRune.ATProto.Repo`
  - [ ] `create_record/2`
  - [ ] `get_record/2`
  - [ ] `put_record/2`
  - [ ] `delete_record/2`
  - [ ] `list_records/2`

**Deliverable**: Working XRPC client with identity resolution and basic repo operations

---

### Phase 3: Bluesky High-Level API (Weeks 5-6)

**Goal**: Easy-to-use Bluesky operations

**Tasks:**
- [ ] `ProtoRune.Bsky.Feed`
  - [ ] `post/2` - create post
  - [ ] `get_timeline/2` - get timeline
  - [ ] `get_post_thread/2` - get thread
  - [ ] `delete_post/2` - delete post
  - [ ] `get_posts/2` - get multiple posts
- [ ] `ProtoRune.Bsky.Graph`
  - [ ] `follow/2` - follow user
  - [ ] `unfollow/2` - unfollow
  - [ ] `block/2` - block user
  - [ ] `unblock/2` - unblock
  - [ ] `mute/2` - mute user
  - [ ] `unmute/2` - unmute
  - [ ] `get_follows/2` - get follows
  - [ ] `get_followers/2` - get followers
- [ ] `ProtoRune.Bsky.Actor`
  - [ ] `get_profile/2` - get profile
  - [ ] `update_profile/2` - update profile
  - [ ] `search_actors/2` - search users
- [ ] `ProtoRune.Bsky.Notification`
  - [ ] `list_notifications/2` - list notifs
  - [ ] `get_unread_count/1` - unread count
  - [ ] `update_seen/2` - mark as seen
- [ ] `ProtoRune.RichText`
  - [ ] `new/0` - create builder
  - [ ] `text/2` - append text
  - [ ] `mention/2` - append mention
  - [ ] `link/3` - append link
  - [ ] `hashtag/2` - append hashtag
  - [ ] `build/1` - finalize

**Deliverable**: Complete high-level Bluesky API with rich text support

---

### Phase 4: Bot Framework (Weeks 7-8)

**Goal**: Event-driven bot development

**Tasks:**
- [ ] `ProtoRune.Bot` behavior
  - [ ] `use` macro
  - [ ] Session management
  - [ ] Event loop
  - [ ] Error handling
- [ ] `ProtoRune.Bot.Poller`
  - [ ] Polling implementation
  - [ ] Notification fetching
  - [ ] Event conversion
  - [ ] Rate limiting
- [ ] Bot events
  - [ ] `:mention` events
  - [ ] `:like` events
  - [ ] `:repost` events
  - [ ] `:follow` events
  - [ ] `:reply` events
- [ ] Supervision
  - [ ] Restart strategies
  - [ ] State recovery
  - [ ] Telemetry events
- [ ] Examples
  - [ ] Greeter bot
  - [ ] Auto-responder
  - [ ] Feed monitor

**Deliverable**: Working bot framework with polling strategy

---

### Phase 5: Advanced Features (Weeks 9-12)

**Goal**: OAuth, Firehose, and polish

**Tasks:**
- [ ] `ProtoRune.OAuth.Client`
  - [ ] Authorization flow
  - [ ] Token exchange
  - [ ] PKCE support
  - [ ] Redirect handling
- [ ] `ProtoRune.Bot.Firehose`
  - [ ] WebSocket connection
  - [ ] CAR file parsing
  - [ ] Event streaming
  - [ ] Filtering
- [ ] `ProtoRune.Bot.Jetstream`
  - [ ] Jetstream client
  - [ ] Event subscription
  - [ ] Filtering
- [ ] Documentation
  - [ ] ExDoc setup
  - [ ] Module docs
  - [ ] Guides
  - [ ] Examples
- [ ] Testing
  - [ ] Unit tests
  - [ ] Integration tests
  - [ ] Mock server
  - [ ] CI/CD
- [ ] Polish
  - [ ] Error messages
  - [ ] Type specs
  - [ ] Dialyzer
  - [ ] Credo

**Deliverable**: v0.2.0 MVP release

---

## Conclusion

This comprehensive proposal provides:

1. **Clear Technical Direction**: Peri-based code generation solves the complexity you encountered with Ecto
2. **Proven Patterns**: Inspired by successful libraries (jacquard, atcute, peri)
3. **Maintainable Architecture**: Clean separation between layers
4. **Developer Experience**: Progressive disclosure from simple to advanced
5. **OTP Integration**: Leverages Elixir's strengths for reliability

**Next Steps:**

1. ✅ Review this document
2. ⏳ Implement Phase 1 (code generation)
3. ⏳ Validate with simple post example
4. ⏳ Continue with Phase 2-5

**Key Decision**: Use Peri instead of Ecto for lexicon schemas. This is the breakthrough that makes the project maintainable and elegant.

Ready to ship a solid MVP! 🚀

---

**Document Version**: 1.0
**Last Updated**: October 2025
**Status**: Proposal for Review
