defmodule Mix.Tasks.ProtoRune.Gen.Lexicon do
  @shortdoc "Generates Elixir modules from AT Protocol lexicons"
  @moduledoc """
  Generates Elixir modules from AT Protocol lexicons.

  This task scans the lexicon directory, parses each lexicon file,
  and generates corresponding Elixir modules with proper types and validation.

  ## Usage

      mix proto_rune.gen.lexicon

      mix proto_rune.gen.lexicon --context app.bsky.*

      mix proto_rune.gen.lexicon --lexicon-dir priv/lexicons --output-dir lib/proto_rune/lexicon

  The task reads lexicons from `priv/lexicons/` and generates modules
  under `lib/proto_rune/lexicons/`.
  """

  use Mix.Task

  alias ProtoRune.Lexicon.Loader

  @lexicon_dir "priv/lexicons"
  @output_dir "lib/proto_rune/lexicons"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Loader.load(@lexicon_dir) do
      {:ok, lexicons} ->
        IO.puts("Loaded #{length(lexicons)} lexicon files")

      {:error, reason} ->
        Mix.raise("Failed to load lexicons: #{inspect(reason)}")
    end
  end
end
