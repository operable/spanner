defmodule Spanner.Bundle.ConfigValidationError do
  defexception message: nil, reason: nil, field: nil
end

defmodule Spanner.Bundle.ConfigValidator do

  use Spanner.JsonNavigator

  alias Spanner.Bundle.ConfigValidationError, as: ValidationError

  def validate(config) when is_binary(config) do
    case Poison.decode(config) do
      {:ok, json} ->
        validate(json)
      {:error, reason} ->
        {:error, {:bad_json, :document, reason}}
    end
  end
  def validate(json) when is_map(json) do
    try do
      validate!(json)
    rescue
      e in ValidationError ->
        {:error, {e.reason, e.field, e.message}}
      e in JsonNavigationError ->
        {:error, {e.reason, e.field, e.message}}
    end
  end

  def validate!(config) when is_binary(config) do
    validate!(Poison.decode!(config))
  end
  def validate!(json) when is_map(json) do
    JsonNavigator.get!(json, ["bundle", {"name", :string}])
    btype = case JsonNavigator.get!(json, ["bundle", {"type", :string}]) do
              type when type in ["foreign", "elixir"] ->
                type
              type ->
                raise ValidationError, field: "type", reason: :wrong_value,
                                       message: "Expected \'foreign\' or \'elixir\' but found \'#{type}\'"
            end
    JsonNavigator.get!(json, [{"permissions", :array}])
    JsonNavigator.get!(json, [{"rules", :array}])
    JsonNavigator.get!(json, [{"templates", :array}])
    commands = JsonNavigator.get!(json, [{"commands", :array}])
    validate_commands!(btype, commands)
  end

  defp validate_commands!(_btype, []), do: :ok
  defp validate_commands!("foreign", [cmd|t]) do
    validate_common_command_fields!(cmd)
    JsonNavigator.get!(cmd, [{"executable", :string}])
    JsonNavigator.get!(cmd, [{"env_vars", :array}])
    validate_commands!("foreign", t)
  end
  defp validate_commands!("elixir", [cmd|t]) do
    validate_common_command_fields!(cmd)
    JsonNavigator.get!(cmd, [{"module", :string}])
    validate_commands!("elixir", t)
  end
  defp validate_common_command_fields!(json) do
    JsonNavigator.get!(json, [{"version", :string}])
    JsonNavigator.get!(json, [{"options", :array}])
    name = JsonNavigator.get!(json, [{"name", :string}])
    enforcing = JsonNavigator.get!(json, [{"enforcing", :boolean}])
    calling_conv = JsonNavigator.get!(json, [{"calling_convention", :string}])
    if calling_conv == "all" and enforcing == true do
      raise ValidationError, field: :enforcing, reason: :incompatible_values,
                             message: "#{name} command cannot enforce permissions with \'all\' calling convention"
    else
      :ok
    end
  end
end