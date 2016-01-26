use Mix.Config

config :logger, :console,
  metadata: [:module, :line],
    format: {Adz, :text}

import_config "#{Mix.env}.exs"
