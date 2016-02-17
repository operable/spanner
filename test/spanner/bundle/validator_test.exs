defmodule Spanner.Bundle.ValidatorTest do

  alias Spanner.Bundle.ConfigValidator
  alias Spanner.Bundle.ConfigValidationError
  alias Spanner.JsonNavigationError

  use ExUnit.Case, async: true

  defp get_config(name) do
    name = name <> ".json"
    path = Path.join("test/assets/configs", name)
    data = File.read!(path)
    Poison.decode!(data)
  end

  defp validate(name) do
    ConfigValidator.validate(get_config(name))
  end

  defp validate!(name) do
    ConfigValidator.validate!(get_config(name))
  end

  test "validates valid Elixir command config" do
    assert validate("valid_elixir_config") == :ok
  end

  test "validates valid foreign command config" do
    assert validate("valid_foreign_config") == :ok
  end

  test "raises on bad uninstall attribute" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_uninstall") end)
    assert error.reason == :wrong_type
    assert error.field == "uninstall"
  end

  test "raises on bad install attribute" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_install") end)
    assert error.reason == :wrong_type
    assert error.field == "install"
  end

  test "raises on bad rule" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_rule") end)
    assert error.reason == :bad_format
    assert error.field == :rules
  end

  test "raises on missing permission in rule" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_missing_perm_rule") end)
    assert error.reason == :incompatible_values
    assert error.field == :rules
  end

  test "raises on bad command option type" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_command_option") end)
    assert error.reason == :wrong_value
    assert error.field == "type"
  end

  test "raises on mismatched bundle name in rule" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_mismatch_bundle") end)
    assert error.reason == :incompatible_values
    assert error.field == :rules
  end

  test "raises on mismatched command name in rule" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_mismatch_command") end)
    assert error.reason == :bad_format
    assert error.field == :rules
  end

  test "raises on bad template format" do
    error = assert_raise(JsonNavigationError, fn() -> validate!("foreign_bad_template") end)
    assert error.reason == :missing_key
    assert error.field == "name"
  end

  test "raises on bad template adapter" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_template_adapter") end)
    assert error.reason == :wrong_value
    assert error.field == "adapter"
  end
end
