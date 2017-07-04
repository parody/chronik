use Mix.Config

config :example, Example.Store,
  adapter: Chronik.Store.Adapters.ETS

config :example, Example.PubSub,
  adapter: Chronik.PubSub.Adapters.Registry
