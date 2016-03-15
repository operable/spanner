defmodule Spanner.Bundle.ValidatorTest do

  alias Spanner.Config

  use ExUnit.Case, async: true

  defp get_config(name) do
    name = name <> ".json"
    path = Path.join("test/assets/configs", name)
    data = File.read!(path)
    Poison.decode!(data)
  end

  defp validate(name) do
    Config.Validator.validate(get_config(name))
  end

  test "validates valid foreign command config" do
    assert validate("valid_foreign_config") == :ok
  end

  test "errors on bad uninstall attribute" do
    response = validate("foreign_bad_uninstall")

    assert response == {:error, [{"Type mismatch. Expected String but got Integer.", "#/bundle/uninstall"}]}
  end

  test "errors on bad install attribute" do
    response = validate("foreign_bad_install")

    assert response == {:error, [{"Type mismatch. Expected String but got Boolean.", "#/bundle/install"}]}
  end

  #test "raises on bad rule" do
    #error = assert_raise(ConfigValidationError, fn() -> validate("foreign_bad_rule") end)
    #assert error.reason == :bad_format
    #assert error.field == :rules
  #end

  #test "raises on missing permission in rule" do
    #error = assert_raise(ConfigValidationError, fn() -> validate("foreign_missing_perm_rule") end)
    #assert error.reason == :incompatible_values
    #assert error.field == :rules
  #end

  test "errors on bad command option type" do
    response = validate("foreign_bad_command_option")

    assert response == {:error, [{"Value \"integer\" is not allowed in enum.", "#/commands/0/options/0/type"}]}
  end

  #test "raises on mismatched bundle name in rule" do
    #error = assert_raise(ConfigValidationError, fn() -> validate("foreign_mismatch_bundle") end)
    #assert error.reason == :incompatible_values
    #assert error.field == :rules
  #end

  #test "raises on mismatched command name in rule" do
    #error = assert_raise(ConfigValidationError, fn() -> validate("foreign_mismatch_command") end)
    #assert error.reason == :bad_format
    #assert error.field == :rules
  #end

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
