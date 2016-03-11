defmodule Spanner.Config.Parser.Test do
  use ExUnit.Case, async: true
  alias Spanner.Config

  test "read_from_string parses valid yaml" do
    yaml = """
    ---
    foo: bar
    biz:
    - baz
    - bliz
    """
    expected = %{"foo" => "bar", "biz" => ["baz", "bliz"]}

    {:ok, results} = Config.Parser.read_from_string(yaml)
    assert results == expected
  end

  test "read_from_string returns an error with bad yaml" do
    yaml = """
    ---
    ]
    """
    {status, _} = Config.Parser.read_from_string(yaml)
    assert status == :error
  end

  test "read_from_file parses valid yaml" do
    expected = %{"foo" => [], "bar" => "bar", "baz" => ["biz", "buz"]}

    {:ok, results} = Config.Parser.read_from_file("test/assets/good.yaml")

    assert results == expected
  end

  test "read_from_file returns an error with bad yaml" do
    {status, _} = Config.Parser.read_from_file("test/assets/bad.yaml")

    assert status == :error
  end

  test "read_from_file returns an error with a bad file path" do
    {status, _} = Config.Parser.read_from_file("foo")

    assert status == :error
  end
end
