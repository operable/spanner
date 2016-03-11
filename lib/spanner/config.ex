defmodule Spanner.Config do
  @config_file "config.yml"
  @dynamic_config_file "config.yml"

  def file_name(),
    do: @config_file

  def dynamic_file_name(),
    do: @dynamic_config_file
end
