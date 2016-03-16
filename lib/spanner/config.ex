defmodule Spanner.Config do
  @config_file "config.yaml"
  @dynamic_config_file "config.yaml"

  def file_name(),
    do: @config_file

  def dynamic_file_name(),
    do: @dynamic_config_file

  def validate(config) do
    with :ok <- Spanner.Config.SyntaxValidator.validate(config),
         :ok <- Spanner.Config.SemanticValidator.validate(config) do
      :ok
    end
  end

end
