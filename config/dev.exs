use Mix.Config

config :chronik, :adapters,
  pub_sub: Chronik.PubSub.Adapters.Registry,
  store: Chronik.Store.Adapters.ETS

config :chronik, ecto_repos: [Chronik.Store.Adapters.Ecto.ChronikRepo]

config :chronik, Chronik.Store.Adapters.Ecto.ChronikRepo,
  adapter: Ecto.Adapters.MySQL,
  url: {:system, "CHRONIK_REPO_URL", "ecto://root:root@localhost/chronik"}

config :chronik, Chronik.Store.Adapters.Ecto,
  aggregate_compression_level: 1,
  domain_event_compression_level: 9,
  json_library: Jason,
  dump_to_json: false
