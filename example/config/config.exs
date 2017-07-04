use Mix.Config

config :chronik, :adapters,
  pubsub: Example.PubSub,
  store: Example.Store

config :example, Example.Store,
  adapter: Chronik.Store.Adapters.ETS

config :example, Example.PubSub,
  adapter: Chronik.PubSub.Adapters.Registry
