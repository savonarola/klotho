defmodule Klotho.MixProject do
  use Mix.Project

  def project do
    [
      app: :klotho,
      description: description(),
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() in [:dev, :test],
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {Klotho.Application, []}
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.10", only: :test},
      {:earmark, "~> 1.4", only: :dev},
      {:ex_doc, "~> 0.23", only: :dev}
    ]
  end

  defp description do
    "Opinionated library for testing timer-based Elixir code"
  end

  defp package do
    [
      name: :klotho,
      files: ["lib", "mix.exs", "*.md", "LICENSE"],
      maintainers: ["Ilya Averyanov"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/savonarola/klotho"
      }
    ]
  end

  defp docs do
    [
      main: "usage",
      extras: [
        "USAGE.md",
        "LICENSE"
      ]
    ]
  end
end
