defmodule Chronik.Mixfile do
  use Mix.Project

  def project do
    [
      app: :chronik,
      version: "0.1.0",
      elixir: "~> 1.5-rc",
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Chronik.Application, []}
    ]
  end

    [
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
