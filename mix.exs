defmodule Chronik.Mixfile do
  use Mix.Project

  @version "0.1.9"

  def project do
    [
      app: :chronik,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      docs: docs(),
      deps: deps(),
      name: "Chronik",
      source_url: "https://github.com/parody/chronik",
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
      source_ref: "v#{@version}",
      main: "Chronik",
      canonical: "http://hexdocs.pm/chronik",
      source_url: "https://github.com/parody/chronik"
    ]
  end

  defp package do
    [
      maintainers: ["Cristian Rosa", "Federico Bergero", "Ricardo Lanziano"],
      licenses: [],
      links: %{"GitHub" => "https://github.com/parody/chronik"},
      files: ~w(mix.exs README.md CHANGELOG.md lib priv config example) ++ ~w(LICENSE TODO.md)
    ]
  end

  defp deps do
    [
      # Development
      {:ex_doc, "> 0.0.0", only: :dev},
      {:dialyxir, "> 0.0.0", only: :dev},
      {:excoveralls, "> 0.0.0", only: :test},
      {:credo, "> 0.0.0", only: :dev},

      # For Ecto-MySQL store
      {:ecto, "~> 2.1"},
      {:mariaex, "~> 0.8.2"},
      {:poison, "~> 3.1.0"},
      {:confex, "~> 3.2.3"}
    ]
  end
end
