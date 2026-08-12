defmodule ProtoRune.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/zoedsoupe/proto_rune"

  def project do
    [
      app: :proto_rune,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      dialyzer: [
        plt_local_path: "priv/plts",
        ignore_warnings: ".dialyzerignore.exs",
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:peri, "~> 0.9"},
      {:req, "~> 0.7"},
      {:gun, "~> 2.2"},
      {:ecto, "~> 3.14"},
      {:styler, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    %{
      name: "proto_rune",
      licenses: ["MIT"],
      contributors: ["zoedsoupe"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/proto_rune"
      },
      files: ~w[lib mix.exs README.md LICENSE]
    }
  end

  defp docs do
    guides = [
      "guides/getting-started.md",
      "guides/authentication.md",
      "guides/posting-content.md",
      "guides/bot-development.md",
      "guides/repository-operations.md",
      "guides/xrpc.md"
    ]

    cheatsheets = [
      "guides/cheatsheets/bluesky.cheatmd"
    ]

    dev = ["README.md", "CONTRIBUTING.md", "LICENSE"]

    [
      main: "readme",
      extras: dev ++ guides ++ cheatsheets,
      groups_for_extras: [
        Guides: guides,
        Cheatsheets: cheatsheets,
        Development: dev
      ]
    ]
  end

  defp description do
    """
    ATProtocol and Bluesky SDK and Bot framework for Elixir
    """
  end
end
