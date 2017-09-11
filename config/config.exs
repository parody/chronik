use Mix.Config

import_config "#{Mix.env}.exs"

config :chronik, ecto_repos: [Chronik.Store.Adapters.Ecto.Repo]
