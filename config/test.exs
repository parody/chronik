use Mix.Config

config :chronik, :adapters,
  pub_sub: Chronik.PubSub.Adapters.Registry,
  store: Chronik.Store.Adapters.ETS

config :chronik, Chronik.Store.Adapters.Ecto.ChronikRepo,
  adapter: Ecto.Adapters.MySQL,
  url: {:system, "CHRONIK_REPO_URL", "ecto://root:root@localhost/chronik"}

config :chronik, Chronik.Aggregate.Test.Counter,
  shutdown_timeout: 1000,
  snapshot_every: 1000
