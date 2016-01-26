use Mix.Config

config :logger, :console,
  metadata: [:module, :line],
    format: {Adz, :text}

config :spanner, :command_config_root,
  Path.join([System.get_env("BUNDLE_CONFIG_ROOT"), "command_configs"])

import_config "#{Mix.env}.exs"
