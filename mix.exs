defmodule Chronik.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :chronik,
      version: @version,
      elixir: "~> 1.5-rc",
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      deps: deps(),
      docs: docs(),

      # Hex
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Chronik.Application, []}
    ]
  end

  defp description do
    """
    A lightweight event sourcing micro framework for Elixir.
    """
  end

  defp docs do
    [
      source_ref: "v#{@version}", main: "Chronik",
      canonical: "http://hexdocs.pm/chronik", logo: "guides/images/chronik.png",
      source_url: "https://github.com/surhive/chronik",
      extras: ["guides/Getting Started.md"]
    ]
  end

  defp package do
    [
      maintainers: ["Cristian Rosa", "Federico Bergero", "Ricardo lanziano"],
      licenses: [],
      links: %{"GitHub" => "https://github.com/surhive/chronik"},
      files: ~w(mix.exs README.md CHANGELOG.md lib) ++
             ~w()
    ]
  end

  defp deps do
    [
      # Documentation
      {:ex_doc, "> 0.0.0", only: :docs},

      # Development
      {:excoveralls, "> 0.0.0", only: :test},
      {:credo, "> 0.0.0", only: :dev}
    ]
  end
end
