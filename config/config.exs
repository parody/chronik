use Mix.Config

config :chronik, :adapters,
  pubsub: Chronik.PubSub.Adapters.Registry,
  store: Chronik.Store.Adapters.ETS
