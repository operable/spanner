defmodule Spanner.JsonNavigatorTest do
  alias Spanner.JsonNavigator

  use ExUnit.Case, async: true

  test "getting values from top level arrays" do
    json = Poison.decode!("[1,2,3,4,5]")
    assert JsonNavigator.get!(json, [{2, :integer}]) == 3
  end

  test "getting values from top level map works" do
    json = Poison.decode!("{\"abc\": 123, \"def\": \"hello\"}")
    assert JsonNavigator.get!(json, [{"def", :string}]) == "hello"
  end

  test "raise error on empty arrays" do
    json = Poison.decode!("{\"templates\": []}")
    error = catch_error(JsonNavigator.get!(json, [{"templates", :array}, 0]))
    assert error.field == 0
    assert error.reason == :wrong_length
  end

  test "raise error on empty maps" do
    json = Poison.decode!("{\"bundle\": {}}")
    error = catch_error(JsonNavigator.get!(json, [{"bundle", :map}, {"type", :string}]))
    assert error.field == "type"
    assert error.reason == :missing_key
  end

  test "navigating nested structures" do
    json = Poison.decode!("{\"commands\": [{\"name\": \"foo\", \"module\": \"Foo.FooCommand\"}]}")
    assert JsonNavigator.get!(json, [{"commands", :array}, {0, :object}, {"name", :string}]) == "foo"
  end
end
