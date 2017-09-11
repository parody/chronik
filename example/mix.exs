defmodule Example.Mixfile do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.5-rc",
      start_permanent: Mix.env == :prod,
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Example.Application, []}
    ]
  end

  defp dialyzer do
    [
      flags: ["-Wunmatched_returns",
              :error_handling,
              :race_conditions,
              :underspecs]
    ]
  end

  defp deps do
    [
      {:dialyxir, "> 0.0.0", only: :dev},
      {:chronik, path: "../"},

      {:excoveralls, "> 0.0.0", only: :test},
      {:credo, "> 0.0.0", only: :dev}
    ]
  end
end
