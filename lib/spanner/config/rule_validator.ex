defmodule Spanner.Config.RuleValidator do

  alias Piper.Permissions.Parser

  @doc """
  Accepts a map of commands and validates their rules
  """
  @spec validate(Map.t) :: :ok | {:ok, [{String.t, String.t}]}
  def validate(commands) do
    validate_rule_parsing(commands)
  end

  defp validate_rule_parsing(commands) when is_map(commands) do
    Enum.flat_map(commands, &validate_rule_parsing/1)
    |> prepare_return
  end
  defp validate_rule_parsing({command, %{"rules" => rules}}) do
    Enum.with_index(rules)
    |> Enum.reduce([], fn({rule, index}, acc) ->
      case Parser.parse(rule) do
        {:ok, _, _} ->
          acc
        {:error, err} ->
          [{err, "#/commands/#{command}/rules/#{index}"}  | acc]
      end
    end)
  end
  defp validate_rule_parsing(_),
    do: []

  defp prepare_return([]),
    do: :ok
  defp prepare_return(errors),
    do: {:error, errors}
end
