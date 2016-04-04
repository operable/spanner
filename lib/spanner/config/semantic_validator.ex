defmodule Spanner.Config.SemanticValidator do

  alias Piper.Permissions.Ast
  alias Piper.Permissions.Parser

  @moduledoc """
  Validates bundle config semantics.
  """


  @doc """
  Accepts a config map and validates semantics.
  """
  @spec validate(Map.t) :: :ok | {:error, [{String.t, String.t}]}
  def validate(config) do
    bundle_name = Map.fetch!(config, "name")
    commands    = Map.fetch!(config, "commands")
    permissions = Map.get(config, "permissions", [])

    errors = commands
    |> Enum.flat_map(&validate_command_rules(&1, bundle_name, permissions))

    case errors do
      [] ->
        :ok
      errors ->
        {:error, errors}
    end
  end

  defp validate_command_rules({command_name, %{"rules" => rules}}, bundle_name, permissions) do
    Enum.with_index(rules)
    |> Enum.flat_map(&validate_rule(&1, bundle_name, command_name, permissions))
  end
  defp validate_command_rules(_, _, _),
    do: []


  defp validate_rule({rule, index}, bundle_name, command_name, permissions) do
    {:ok, %Ast.Rule{}=expr, rule_permissions} = Parser.parse(rule)
    [rule_bundle, rule_command] = String.split(expr.command, ":", parts: 2)

    errors = [validate_bundle(rule_bundle, bundle_name),
              validate_command(rule_command, command_name),
              validate_permissions(rule_permissions, permissions)]

    errors
    |> List.flatten
    |> Enum.map(&{&1, "#/commands/#{command_name}/rules/#{index}"})
  end

  defp validate_bundle(bundle, bundle),
    do: []
  defp validate_bundle(rule_bundle, bundle),
    do: ["The bundle name '#{bundle}' does not match the name in the bundle, '#{rule_bundle}'."]

  defp validate_command(command, command),
    do: []
  defp validate_command(rule_command, command_name),
    do: ["The command name '#{command_name}' does not match the name in it's rule, '#{rule_command}'."]

  defp validate_permissions(rule_permissions, permissions) do
    missing_permissions = MapSet.difference(MapSet.new(rule_permissions), MapSet.new(permissions)) |> MapSet.to_list

    Enum.map(missing_permissions, fn permission ->
      "The permission '#{permission}' is not in the list of permissions."
    end)
  end

end
