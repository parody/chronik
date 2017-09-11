use Mix.Config

config :chronik, :adapters,
  pub_sub: Example.PubSub,
  store: Example.Store

config :example, Example.Store,
  adapter: Chronik.Store.Adapters.ETS

config :example, Example.PubSub,
  adapter: Chronik.PubSub.Adapters.Registry

config :chronik, Chronik.Store.Adapters.Ecto.Repo,
  adapter: Ecto.Adapters.MySQL,
  database: "chronik",
  username: "root",
  password: "root",
  hostname: "localhost"
