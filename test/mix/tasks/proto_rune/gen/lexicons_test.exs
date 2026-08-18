defmodule Mix.Tasks.ProtoRune.Gen.LexiconsTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.ProtoRune.Gen.Lexicons

  @lexicon """
  {
    "lexicon": 1,
    "id": "com.example.feed.post",
    "defs": {
      "main": {
        "type": "record",
        "key": "tid",
        "record": {
          "type": "object",
          "required": ["text"],
          "properties": {
            "text": {"type": "string"}
          }
        }
      }
    }
  }
  """

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Quiet)

    tmp_dir = System.tmp_dir!()
    lexicons_dir = Path.join(tmp_dir, "lexicons_#{System.unique_integer([:positive])}")
    output_dir = Path.join(tmp_dir, "output_#{System.unique_integer([:positive])}")

    File.mkdir_p!(lexicons_dir)
    File.write!(Path.join(lexicons_dir, "com.example.feed.post.json"), @lexicon)

    on_exit(fn ->
      Mix.shell(previous_shell)
      File.rm_rf!(lexicons_dir)
      File.rm_rf!(output_dir)
    end)

    {:ok, lexicons_dir: lexicons_dir, output_dir: output_dir}
  end

  test "--path and --output generate modules into the given directories", %{
    lexicons_dir: lexicons_dir,
    output_dir: output_dir
  } do
    Lexicons.run(["--path", lexicons_dir, "--output", output_dir])

    generated = Path.join(output_dir, "com/example/feed/post.ex")
    assert File.exists?(generated)
    assert generated |> File.read!() |> String.contains?("defmodule ProtoRune.Lexicon.Com.Example.Feed.Post")
  end

  test "legacy --lexicons-dir and --output-dir flags still work", %{
    lexicons_dir: lexicons_dir,
    output_dir: output_dir
  } do
    Lexicons.run(["--lexicons-dir", lexicons_dir, "--output-dir", output_dir])

    assert File.exists?(Path.join(output_dir, "com/example/feed/post.ex"))
  end
end
