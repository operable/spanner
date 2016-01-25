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

  test "raises on bad postinstall attribute" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_postinstall") end)
    assert error.reason == :wrong_type
    assert error.field == "postinstall"
  end

  test "raises on bad preinstall attribute" do
    error = assert_raise(ConfigValidationError, fn() -> validate!("foreign_bad_preinstall") end)
    assert error.reason == :wrong_type
    assert error.field == "preinstall"
  end

end
