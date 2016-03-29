defmodule Spanner.Config do
  @config_extensions [".yaml", ".yml", ".json"]
  @config_file "config"

  @doc "Returns a list of valid config extensions"
  def config_extensions(),
    do: @config_extensions

  @doc "Determine if a given path points to a config file"
  def config_file?(filename) do
    String.ends_with?(filename, Enum.map(config_extensions, &("#{@config_file}#{&1}")))
  end

  @doc "Validate bundle configs"
  def validate(config) do
    with :ok <- Spanner.Config.SyntaxValidator.validate(config),
         :ok <- Spanner.Config.SemanticValidator.validate(config) do
      :ok
    end
  end

end
