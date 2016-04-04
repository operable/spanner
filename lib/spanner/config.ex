defmodule Spanner.Config do
  @config_extensions [".yaml", ".yml", ".json"]
  @config_file "config"

  @doc "Returns a list of valid config extensions"
  def config_extensions,
    do: @config_extensions

  @doc "Returns the config file name sans extensions"
  def config_file_name,
    do: @config_file

  @doc "Return all config files in directory via `Path.wildcard/1`"
  def find_configs(base_dir) do
    extensions = Enum.join(config_extensions, ",")
    Path.wildcard("#{base_dir}/#{config_file_name}{#{extensions}}")
  end

  @doc "Determine if a given path points to a config file"
  def config_file?(filename) do
    String.ends_with?(filename, Enum.map(config_extensions, &("#{@config_file}#{&1}")))
  end

  @doc "Determine if a given path points to a file with a valid config extension"
  def config_extension?(filename) do
    String.ends_with?(filename, Enum.map(config_extensions, &("#{&1}")))
  end

  @doc """
  Fills in missing prefix for rules with shortened syntax. ie, rules without the
  'when command is bundle:command' part. This should occur automatically whenever
  a config file is parsed or validated.

  ex: 'must have bundle:permission' -> 'when command is bundle:command must have bundle:permission'
  """
  def fixup_rules(%{"commands" => commands}=config) do
    Map.keys(commands)
    |> Enum.reduce(config, &update_rules/2)
  end
  def fixup_rules(config),
    do: config

  @doc "Validate bundle configs"
  def validate(config) do
    with fixed_config = fixup_rules(config),
         :ok <- Spanner.Config.SyntaxValidator.validate(fixed_config),
         :ok <- Spanner.Config.SemanticValidator.validate(fixed_config) do
      :ok
    end
  end

  defp fix_rules(bundle_command, rules) do
    Enum.map(rules, &fix_rule(bundle_command, &1))
  end

  defp fix_rule({bundle, command}, rule) do
    if String.starts_with?(String.downcase(rule), "when command is") do
      rule
    else
      "when command is #{bundle}:#{command} #{rule}"
    end
  end

  defp update_rules(command, %{"name" => name}=config) do
    if get_in(config, ["commands", command, "rules"]) do
      update_in(config, ["commands", command, "rules"], &fix_rules({name,command}, &1))
    else
      config
    end
  end

end
