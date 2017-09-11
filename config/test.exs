use Mix.Config

config :chronik, :adapters,
  pub_sub: Chronik.PubSub.Adapters.Registry,
  store: Chronik.Store.Adapters.ETS

config :chronik, Chronik.Store.Adapters.Ecto,
  store: Chronik.Store.Adapters.Ecto.Repo

config :chronik, Chronik.Store.Adapters.Ecto.Repo,
  adapter: Ecto.Adapters.MySQL,
  database: "chronik",
  username: "root",
  password: "root",
  hostname: "localhost"
