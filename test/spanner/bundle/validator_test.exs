defmodule Spanner.Bundle.ValidatorTest do

  alias Spanner.Bundle.ConfigValidator
  alias Spanner.Bundle.ConfigValidationError

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

end
