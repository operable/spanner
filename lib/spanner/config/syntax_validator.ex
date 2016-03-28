defmodule Spanner.Config.SyntaxValidator do

  alias Piper.Permissions.Parser

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
         :ok <- validate_rule_parsing(config["rules"]) do
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

  defp validate_rule_parsing(nil),
    do: :ok
  defp validate_rule_parsing(rules) do
    Enum.with_index(rules)
    |> Enum.reduce([], fn({rule, index}, acc) ->
      case Parser.parse(rule) do
        {:ok, _, _} ->
          acc
        {:error, err} ->
          [{err, "#/rules/#{index}"}  | acc]
      end
    end)
    |> prepare_return
  end

  defp prepare_return([]),
    do: :ok
  defp prepare_return(errors),
    do: {:error, errors}

  defp load_schema(name) do
    # Returns absolute path to spanner/priv
    priv_dir = :code.priv_dir(:spanner)

    # path will be a string like
    # /Users/kevsmith/work/cog/_build/dev/lib/spanner/priv/schemas/<name>.yaml
    path = Path.join([priv_dir, "schemas", name <> ".yaml"])

    Spanner.Config.Parser.read_from_file(path)
  end
end
