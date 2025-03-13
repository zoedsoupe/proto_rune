defmodule ProtoRune.MixProject do
  use Mix.Project

  @version "0.1.2"
  @source_url "https://github.com/zoedsoupe/proto_rune"

  def project do
    [
      app: :proto_rune,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      dialyzer: [plt_local_path: "priv/plts", ignore_warnings: ".dialyzerignore.exs"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ProtoRune.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:peri, "~> 0.4.0-rc1"},
      {:req, "~> 0.5"},
      {:ecto, "~> 3.12"},
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
      "guides/getting_started.md",
      "guides/records.md",
      "guides/xrpc.md",
      "guides/bots.md",
      "guides/identity.md"
    ]

    dev = ["README.md", "CONTRIBUTING.md", "LICENSE", "rfc.md"]

    [
      main: "getting_started",
      extras: dev ++ guides,
      groups_for_extras: [
        Guides: guides,
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
