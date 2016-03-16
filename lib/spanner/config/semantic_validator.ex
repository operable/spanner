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
    verify_rules(config)
  end

  defp verify_rules(config) do
    permission_set = MapSet.new(config["permissions"])

    Enum.with_index(config["rules"])
    |> Enum.reduce([], fn({rule, index}, acc) ->
      {:ok, %Ast.Rule{}=expr, rule_perms} = Parser.parse(rule)
      [bundle, command] = String.split(expr.command, ":", parts: 2)

      if config["bundle"]["name"] != bundle do
        acc = [{"The bundle name '#{bundle}' does not match the name in the bundle", "#/rules/#{index}"}  | acc]
      end
      if not(command) in Enum.map(config["commands"], &Map.fetch!(&1, "name")) do
        acc = [{"The command '#{expr.command}' is not in the list of commands", "#/rules/#{index}"}  | acc]
      end

      case MapSet.difference(MapSet.new(rule_perms), permission_set) |> MapSet.to_list do
        [] ->
          acc
        bad_perms ->
          Enum.map(bad_perms, fn(bad_perm) ->
            {"The permission '#{bad_perm}' is not in the list of permissions.", "#/rules/#{index}"}
          end) ++ acc
      end
    end)
    |> (fn ([]) -> :ok
           (errors) -> {:error, errors}
        end).()
  end

end
