defmodule Spanner.Bundle.ConfigValidationError do
  defexception message: nil, reason: nil, field: nil
end

defmodule Spanner.Bundle.ConfigValidator do

  use Spanner.JsonNavigator

  alias Spanner.Bundle.ConfigValidationError, as: ValidationError
  alias Piper.Permissions.Parser
  alias Piper.Permissions.Ast

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
    bundle_name = JsonNavigator.get!(json, ["bundle", {"name", :string}])
    templates = JsonNavigator.get!(json, [{"templates", :array}])
    validate_templates!(templates)
    validate_optional_attributes!(json["bundle"], [{"install", :string}, {"uninstall", :string}])
    commands = JsonNavigator.get!(json, [{"commands", :array}])
    permissions = JsonNavigator.get!(json, [{"permissions", :array}])
    rules = JsonNavigator.get!(json, [{"rules", :array}])
    validate_rules!(rules, permissions, commands, bundle_name)
    validate_commands!(commands)
  end

  # Validate Commands
  defp validate_commands!([]), do: :ok
  defp validate_commands!([cmd|remaining]) do
    validate_common_command_fields!(cmd)
    JsonNavigator.get!(cmd, [{"executable", :string}])
    JsonNavigator.get!(cmd, [{"env_vars", :map}])
    validate_commands!(remaining)
  end

  defp validate_common_command_fields!(json) do
    JsonNavigator.get!(json, [{"version", :string}])
    options = JsonNavigator.get!(json, [{"options", :array}])
    validate_options!(options)
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

  # Validate Command Options
  defp validate_options!([]), do: :ok
  defp validate_options!([option|rem_options]) do
    JsonNavigator.get!(option, [{"name", :string}])
    JsonNavigator.get!(option, [{"required", :boolean}])
    case JsonNavigator.get!(option, [{"type", :string}]) do
      type when type in ["int", "string", "bool"] ->
        :ok
      type ->
        raise ValidationError, field: "type", reason: :wrong_value,
                               message: "Expected 'string', 'int', or 'bool' but found '#{type}'"
    end
    validate_options!(rem_options)
  end

  # Validate Rules
  defp validate_rules!([], [], _, _), do: :ok
  defp validate_rules!(rules, permissions, commands, bundle_name) when is_list(rules),
    do: Enum.map(rules, &validate_rules!(&1, permissions, commands, bundle_name))

  defp validate_rules!(rule, permissions, commands, bundle_name) do
    case Parser.parse(rule) do
      {:ok, %Ast.Rule{}=expr, rule_perms} ->
        Enum.map(rule_perms, &verify_rule_permissions!(&1, permissions))
        verify_rule_commands!(expr.command, Enum.map(commands, &Map.fetch!(&1, "name")), bundle_name)
      {:error, error} ->
        raise ValidationError, field: :rules, reason: :bad_format,
                               message: error
    end
  end

  defp verify_rule_permissions!(rule_perms, permissions) do
    if rule_perms in permissions do
      :ok
    else
      raise ValidationError, field: :rules, reason: :incompatible_values,
                             message: "The permission #{rule_perms} used in the rule is not in the list of permissions"
    end
  end

  defp verify_rule_commands!(rule_command, commands, bundle_name) do
    [bundle, command] = String.split(rule_command, ":")
    if bundle_name != bundle do
      raise ValidationError, field: :rules, reason: :incompatible_values,
                             message: "The bundle name in the rule #{rule_command} does not match the name in the bundle"
    end
    if command in commands do
      :ok
    else
      raise ValidationError, field: :rules, reason: :bad_format,
                             message: "The command #{rule_command} used in the rule is not in the list of commands"
    end
  end

  # Validate Templates
  defp validate_templates!([]), do: :ok
  defp validate_templates!([cmd|t]) do
    JsonNavigator.get!(cmd, [{"name", :string}])
    JsonNavigator.get!(cmd, [{"path", :string}])
    adapter = JsonNavigator.get!(cmd, [{"adapter", :string}])
    case String.downcase(adapter) do
      type when type in ["slack", "hipchat"] ->
        type
      _ ->
        raise ValidationError, field: "adapter", reason: :wrong_value,
                               message: "Unknown adapter '#{adapter}'"
    end
    validate_templates!(t)
  end

  # Validate Optional Attributes (e.g.: install, uninstall)
  defp validate_optional_attributes!(_json, []) do
    :ok
  end
  defp validate_optional_attributes!(json, [attr|t]) do
    try do
      JsonNavigator.get!(json, [attr])
    rescue
      e in JsonNavigationError ->
        if e.reason != :missing_key do
          raise ValidationError, field: e.field, reason: e.reason, message: e.message
        end
    end
    validate_optional_attributes!(json, t)
  end
end
