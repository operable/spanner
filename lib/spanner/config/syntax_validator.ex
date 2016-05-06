defmodule Spanner.Config.SyntaxValidator do

  @schema_file_v2 Path.join([:code.priv_dir(:spanner), "schemas", "bundle_config_schema_v2.yaml"])
  @schema_file_v3 Path.join([:code.priv_dir(:spanner), "schemas", "bundle_config_schema_v3.yaml"])

  @external_resource @schema_file_v2
  @external_resource @schema_file_v3

  @schema_v2 File.read!(@schema_file_v2)
  @schema_v3 File.read!(@schema_file_v3)

  @moduledoc """
  Validates bundle config syntax leveraging JsonSchema.
  """

  @doc """
  Accepts a config map and validates syntax.
  """
  @spec validate(Map.t, integer()) :: :ok | {:error, [{String.t, String.t}]}
  def validate(config, version \\ 3) do
    # Note: We could validate command calling convention with ExJsonEchema
    # but the error that it returned was less than informative so instead
    # we just do it manually. It may be worth revisiting in the future.
    with {:ok, schema} <- load_schema(version),
         {:ok, resolved_schema} <- resolve_schema(schema),
         :ok <- ExJsonSchema.Validator.validate(resolved_schema, config),
       do: :ok
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

  defp load_schema(2),
    do: Spanner.Config.Parser.read_from_string(@schema_v2)
  defp load_schema(_),
    do: Spanner.Config.Parser.read_from_string(@schema_v3)
end
