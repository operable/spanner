defmodule Spanner.Bundle.ValidatorTest do

  alias Spanner.Bundle.ConfigValidator
  alias Spanner.Bundle.ConfigValiationError

  use ExUnit.Case, async: true

  defp get_config(name) do
    name = name <> ".json"
    path = Path.join("test/assets/configs", name)
    data = File.read!(path)
    Poison.decode!(data)
  end

  test "validates valid Elixir command config" do
    assert ConfigValidator.validate(get_config("valid_elixir_config")) == :ok
  end

  test "validates valid foreign command config" do
    assert ConfigValidator.validate(get_config("valid_foreign_config")) == :ok
  end

end
