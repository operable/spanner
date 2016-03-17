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
    rules       = Map.get(config, "rules", [])
    bundle      = Map.fetch!(config, "bundle")
    commands    = Map.fetch!(config, "commands")
    permissions = Map.get(config, "permissions", [])

    errors = rules
    |> Enum.with_index
    |> Enum.flat_map(&validate_rule(&1, bundle, commands, permissions))

    case errors do
      [] ->
        :ok
      errors ->
        {:error, errors}
    end
  end

  defp validate_rule({rule, index}, bundle, commands, permissions) do
    {:ok, %Ast.Rule{}=expr, rule_permissions} = Parser.parse(rule)
    [rule_bundle, rule_command] = String.split(expr.command, ":", parts: 2)

    errors = [validate_bundle(rule_bundle, bundle["name"]),
              validate_command(rule_command, commands),
              validate_permissions(rule_permissions, permissions)]

    errors
    |> List.flatten
    |> Enum.map(&{&1, "#/rules/#{index}"})
  end

  defp validate_bundle(bundle, bundle),
    do: []
  defp validate_bundle(rule_bundle, bundle),
    do: ["The bundle name '#{bundle}' does not match the name in the bundle, '#{rule_bundle}'."]

  defp validate_command(rule_command, commands) do
    command_names = Enum.map(commands, &Map.fetch!(&1, "name"))

    case rule_command in command_names do
      true ->
        []
      false ->
        ["The command '#{rule_command}' is not in the list of commands"]
    end
  end

  defp validate_permissions(rule_permissions, permissions) do
    missing_permissions = MapSet.difference(MapSet.new(rule_permissions), MapSet.new(permissions)) |> MapSet.to_list

    Enum.map(missing_permissions, fn permission ->
      "The permission '#{permission}' is not in the list of permissions."
    end)
  end

end
