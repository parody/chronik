use Mix.Config

config :ecto, json_library: Jason

import_config "#{Mix.env}.exs"
