defmodule Mix.Tasks.ProtoRune.Gen.Lexicons do
  @shortdoc "Generates Peri schema modules from ATProto lexicon files"

  @moduledoc """
  Generates Peri schema modules from ATProto lexicon JSON files.

  This task reads lexicon definitions from `priv/atproto/lexicons` and generates
  corresponding Elixir modules with Peri schemas in `lib/proto_rune/lexicon/`.

  ## Usage

      $ mix proto_rune.gen.lexicons

  ## Options

    * `--lexicons-dir` - Directory containing lexicon JSON files (default: priv/atproto/lexicons)
    * `--output-dir` - Directory where generated modules will be written (default: lib/proto_rune/lexicon/)
    * `--recursive` - Recursively search for lexicon files in subdirectories (default: true)
    * `--force` - Force regeneration even if output files exist (default: false)

  ## Examples

      # Generate all lexicons with default settings
      $ mix proto_rune.gen.lexicons

      # Specify custom directories
      $ mix proto_rune.gen.lexicons --lexicons-dir custom/lexicons --output-dir custom/output

      # Force regeneration
      $ mix proto_rune.gen.lexicons --force

  ## Generated Files

  For each lexicon file `app.bsky.feed.post.json`, this task will generate:

    * `lib/proto_rune/lexicon/app/bsky/feed/post.ex`

  Each generated module will contain:

    * Module documentation from the lexicon description
    * Peri `defschema` definitions for all defs in the lexicon
    * Helper functions for validation

  ## Notes

    * Generated files should be committed to git for version control
    * If lexicon files are updated, re-run this task to regenerate modules
    * Generated modules are not meant to be edited manually
  """

  use Mix.Task

  alias ProtoRune.Lexicon.Generator

  @default_lexicons_dir "priv/atproto/lexicons"
  @default_output_dir "lib/proto_rune/lexicon"

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          lexicons_dir: :string,
          output_dir: :string,
          recursive: :boolean,
          force: :boolean
        ]
      )

    lexicons_dir = Keyword.get(opts, :lexicons_dir, @default_lexicons_dir)
    output_dir = Keyword.get(opts, :output_dir, @default_output_dir)
    recursive = Keyword.get(opts, :recursive, true)
    force = Keyword.get(opts, :force, false)

    Mix.shell().info("Generating lexicon modules...")
    Mix.shell().info("Lexicons directory: #{lexicons_dir}")
    Mix.shell().info("Output directory: #{output_dir}")

    case validate_directories(lexicons_dir, output_dir, force) do
      :ok ->
        generate_lexicons(lexicons_dir, output_dir, recursive)

      {:error, reason} ->
        Mix.shell().error("Error: #{format_error(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp validate_directories(lexicons_dir, output_dir, force) do
    cond do
      not File.dir?(lexicons_dir) ->
        {:error, {:no_lexicons_dir, lexicons_dir}}

      File.dir?(output_dir) and not force and has_files?(output_dir) ->
        {:error, {:output_dir_exists, output_dir}}

      true ->
        :ok
    end
  end

  defp has_files?(dir) do
    case File.ls(dir) do
      {:ok, files} -> length(files) > 0
      _ -> false
    end
  end

  defp generate_lexicons(lexicons_dir, output_dir, recursive) do
    lexicon_files = find_lexicon_files(lexicons_dir, recursive)

    if Enum.empty?(lexicon_files) do
      Mix.shell().error("No lexicon files found in #{lexicons_dir}")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(lexicon_files)} lexicon file(s)")
    Mix.shell().info("")

    results =
      lexicon_files
      |> Enum.with_index(1)
      |> Enum.map(fn {file, index} ->
        generate_single_lexicon(file, output_dir, index, length(lexicon_files))
      end)

    successes = Enum.count(results, &match?(:ok, &1))
    failures = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info("")
    Mix.shell().info("Generation complete!")
    Mix.shell().info("  ✓ #{successes} module(s) generated successfully")

    if failures > 0 do
      Mix.shell().error("  ✗ #{failures} module(s) failed to generate")
      exit({:shutdown, 1})
    end
  end

  defp find_lexicon_files(dir, recursive) do
    pattern = if recursive, do: "**/*.json", else: "*.json"
    full_pattern = Path.join(dir, pattern)

    full_pattern
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp generate_single_lexicon(file, output_dir, index, total) do
    relative_path = Path.relative_to_cwd(file)
    Mix.shell().info("[#{index}/#{total}] Processing #{relative_path}...")

    with {:ok, content} <- File.read(file),
         {:ok, lexicon} <- Jason.decode(content),
         {:ok, source} <- Generator.generate_module(lexicon),
         file_path = Generator.module_file_path(lexicon["id"], output_dir),
         :ok <- ensure_parent_dir(file_path),
         :ok <- File.write(file_path, source) do
      output_relative = Path.relative_to_cwd(file_path)
      Mix.shell().info("  → Generated #{output_relative}")
      :ok
    else
      {:error, reason} ->
        Mix.shell().error("  ✗ Failed: #{format_error(reason)}")
        {:error, reason}
    end
  end

  defp ensure_parent_dir(file_path) do
    file_path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp format_error({:no_lexicons_dir, dir}), do: "Lexicons directory does not exist: #{dir}"

  defp format_error({:output_dir_exists, dir}), do: "Output directory already exists: #{dir}. Use --force to overwrite."

  defp format_error({:generation_failed, message}), do: "Generation failed: #{message}"

  defp format_error(%Jason.DecodeError{} = error), do: "JSON decode error: #{Exception.message(error)}"
  defp format_error(reason), do: inspect(reason)
end
