defmodule Spanner.Config.SyntaxValidator do

  @current_config_version Spanner.Config.current_config_version
  @old_config_version @current_config_version - 1

  @current_schema_file Path.join([:code.priv_dir(:spanner), "schemas", "bundle_config_schema_v#{@current_config_version}.yaml"])
  @old_schema_file Path.join([:code.priv_dir(:spanner), "schemas", "bundle_config_schema_v#{@old_config_version}.yaml"])

  @external_resource @current_schema_file
  @external_resource @old_schema_file

  @current_schema File.read!(@current_schema_file)
  @old_schema File.read!(@old_schema_file)

  @moduledoc """
  Validates bundle config syntax leveraging JsonSchema.
  """

  @doc """
  Accepts a config map and validates syntax.
  """
  @spec validate(Map.t) :: :ok | {:error, [{String.t, String.t}]}
  def validate(config) do
    with version <- Map.fetch!(config, "cog_bundle_version"),
         {:ok, schema} <- load_schema(version),
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

  defp load_schema(@old_config_version),
    do: Spanner.Config.Parser.read_from_string(@old_schema)
  defp load_schema(_),
    do: Spanner.Config.Parser.read_from_string(@current_schema)
end
