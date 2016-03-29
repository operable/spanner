defmodule Spanner.Config do
  @config_extensions [".yaml", ".yml", ".json"]
  @config_file "config.yaml"
  @dynamic_config_file "config.yaml"

  def file_name(),
    do: @config_file

  def dynamic_file_name(),
    do: @dynamic_config_file

  def config_extensions(),
    do: @config_extensions

  def config_file?(filename) do
    String.ends_with?(filename, config_extensions)
  end

  def validate(config) do
    with :ok <- Spanner.Config.SyntaxValidator.validate(config),
         :ok <- Spanner.Config.SemanticValidator.validate(config) do
      :ok
    end
  end

end
