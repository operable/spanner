defmodule Spanner.Config.SyntaxValidator do

  alias Piper.Permissions.Parser

  @schema File.read!(Path.join([:code.priv_dir(:spanner), "schemas", "bundle_config_schema.yaml"]))

  @moduledoc """
  Validates bundle config syntax leveraging JsonSchema.
  """

  @doc """
  Accepts a config map and validates syntax. Validate does three major checks.
  An error can be returned during any one of these. First it does some basic
  validation on the config using JsonSchema. Last we validate that all rules
  at least parse.
  """
  @spec validate(Map.t) :: :ok | {:ok, [{String.t, String.t}]}
  def validate(config) do
    # Note: We could validate command calling convention with ExJsonEchema
    # but the error that it returned was less than informative so instead
    # we just do it manually. It may be worth revisiting in the future.
    with {:ok, schema} <- load_schema("bundle_config_schema"),
         {:ok, resolved_schema} <- resolve_schema(schema),
         :ok <- ExJsonSchema.Validator.validate(resolved_schema, config),
         :ok <- validate_rule_parsing(config["commands"]) do
           :ok
    end
  end

  # Resolves our internal config schema. If the schema fails to resolve we
  # return an error tuple.
  # Note: The call to resolve can be expensive. Reading the documentation
  # suggests using a genserver and keeping the resolved schema in state.
  # Since we are just resolving once during install I think it will be ok
  # for now. But we may want to revisit.
  defp resolve_schema(schema) do
    try do
      {:ok, ExJsonSchema.Schema.resolve(schema)}
    rescue
      err in [ExJsonSchema.Schema.InvalidSchemaError] ->
        {:error, "Invalid config schema: #{inspect err}"}
    end
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

  defp load_schema(_name) do
    Spanner.Config.Parser.read_from_string(@schema)
  end
end
