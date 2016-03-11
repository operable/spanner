defmodule Spanner.Config do
  @config_file "config.yml"

  def file_name(),
    do: @config_file
end
