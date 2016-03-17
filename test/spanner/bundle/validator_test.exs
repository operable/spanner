defmodule Spanner.Bundle.ValidatorTest do

  alias Spanner.Config

  use ExUnit.Case, async: true

  defp get_config(name) do
    name = name <> ".yaml"
    path = Path.join("test/assets/configs", name)
    {:ok, config} = Spanner.Config.Parser.read_from_file(path)
    config
  end

  defp validate(name) do
    Config.validate(get_config(name))
  end

  test "templates should be optional" do
    assert validate("no_templates") == :ok
  end

  test "rules should be optional" do
    assert validate("no_rules") == :ok
  end

  test "permissions should be optional when there are no rules" do
    assert validate("no_perms_or_rules") == :ok
  end

  test "errors when permissions don't match rules" do
    response = validate("no_permissions")

    assert response == {:error, [{"The permission 'date:view' is not in the list of permissions.", "#/rules/0"}]}
  end

  test "validates valid foreign command config" do
    assert validate("valid_foreign_config") == :ok
  end

  test "errors on bad rule" do
    response = validate("foreign_bad_rule")

    assert response == {:error, [{"(Line: 1, Col: 34) References to permissions must start with a command bundle name or \"site\".", "#/rules/0"}]}
  end

  test "errors when enforcing commands use the 'all' calling convention" do
    response = validate("foreign_bad_enforcing_command")

    assert response == {:error, [{"Enforcing commands must use the bound calling convention.", "#/commands/0/calling_convention"}]}
  end

  test "errors on bad uninstall attribute" do
    response = validate("foreign_bad_uninstall")

    assert response == {:error, [{"Type mismatch. Expected String but got Integer.", "#/bundle/uninstall"}]}
  end

  test "errors on bad install attribute" do
    response = validate("foreign_bad_install")

    assert response == {:error, [{"Type mismatch. Expected String but got Boolean.", "#/bundle/install"}]}
  end

  test "errors on bad command option type" do
    response = validate("foreign_bad_command_option")

    assert response == {:error, [{"Value \"integer\" is not allowed in enum.", "#/commands/0/options/0/type"}]}
  end

  test "errors on bad template format" do
    response = validate("foreign_bad_template")

    assert response == {:error, [{"Required property name was not present.", "#/templates/0"},
                                 {"Required property adapter was not present.", "#/templates/0"},
                                 {"Required property path was not present.", "#/templates/0"}]}
  end

  test "errors on bad template adapter" do
    response = validate("foreign_bad_template_adapter")

    assert response == {:error, [{"Value \"meh\" is not allowed in enum.", "#/templates/0/adapter"}]}
  end

  test "does not raise with no bundle type (assumes foreign bundle)" do
    assert validate("valid_foreign_config_without_type") == :ok
  end
end
