defmodule Spanner.Config.Validator.Test do
  use ExUnit.Case, async: true
  alias Spanner.Config

  defp validate(config) do
    case Config.validate(config) do
      {:ok, _} ->
        :ok
      error ->
        error
    end
  end

  defp minimal_config do
    %{"cog_bundle_version" => 2,
      "name" => "foo",
      "version" => "0.0.1",
      "commands" => %{
        "date" => %{
          "executable" => "/bin/date"
        }
      }
    }
  end

  defp enforcing_config do
    %{"cog_bundle_version" => 2,
      "name" => "foo",
      "version" => "0.0.1",
      "commands" => %{
        "bar" => %{
          "executable" => "/bin/bar",
          "enforcing" => true}}}
  end

  defp bad_enforcing_config do
    %{"cog_bundle_version" => 2,
      "name" => "foo",
      "version" => "0.0.1",
      "commands" => %{
        "bar" => %{
          "executable" => "/bin/bar",
          "enforcing" => "true"}}}
  end

  defp execution_config do
    %{"cog_bundle_version" => 2,
      "name" => "foo",
      "version" => "0.1",
      "commands" => %{
        "bar" => %{"executable" => "/bin/bar",
                   "enforcing" => false,
                   "execution" => "once"},
        "baz" => %{"executable" => "/bin/baz",
                   "execution" => "multiple"}}}
  end

  defp bad_execution_config do
    %{"cog_bundle_version" => 2,
      "name" => "foo",
      "version" => "0.1",
      "commands" => %{
        "bar" => %{"executable" => "/bin/bar",
                   "execution" => "once"},
        "baz" => %{"executable" => "/bin/baz",
                   "execution" => "multi"}}}
  end

  defp incomplete_rules_config do
    %{"cog_bundle_version" => 2,
      "name" => "foo",
      "version" => "0.1",
      "permissions" => ["foo:view"],
      "commands" => %{
        "bar" => %{"executable" => "/bin/bar",
                   "execution" => "once",
                   "rules" => ["must have foo:view"]},
        "baz" => %{"executable" => "/bin/baz",
                   "execution" => "multiple"}}}
  end



  test "minimal config" do
    assert validate(minimal_config) == :ok
  end

  test "bad bundle versions" do
    updated = put_in(minimal_config, ["version"], "1")
    assert validate(updated) == {:error, [{"String \"1\" does not match pattern \"^\\\\d+\\\\.\\\\d+($|\\\\.\\\\d+$)\".", "#/version"}]}
    updated = put_in(minimal_config, ["version"], "0.0.1-beta")
    assert validate(updated) == {:error, [{"String \"0.0.1-beta\" does not match pattern \"^\\\\d+\\\\.\\\\d+($|\\\\.\\\\d+$)\".", "#/version"}]}
  end

  test "wrong cog_bundle_version" do
    result = update_in(minimal_config, ["cog_bundle_version"], fn(_) -> 1 end)
    |> validate
    assert result == {:error, [{"Value 1 is not allowed in enum.", "#/cog_bundle_version"}]}
  end

  test "missing cog_bundle_version" do
    result = Map.delete(minimal_config, "cog_bundle_version") |> validate
    assert result == {:error, [{"Required property cog_bundle_version was not present.", "#"}]}
  end

  test "enforcing config" do
    assert validate(enforcing_config) == :ok
  end

  test "bad enforcing config" do
    assert validate(bad_enforcing_config) == {:error,
                                              [{"Type mismatch. Expected Boolean but got String.",
                                                "#/commands/bar/enforcing"}]}
  end

  test "execution_config" do
    assert validate(execution_config) == :ok
  end

  test "bad_execution_config" do
    assert validate(bad_execution_config) == {:error, [{"Value \"multi\" is not allowed in enum.", "#/commands/baz/execution"}]}
  end

  test "incomplete rules" do
    assert validate(incomplete_rules_config) == :ok
  end

  test "rules are fixed up" do
    {:ok, config} = Spanner.Config.validate(incomplete_rules_config)
    [rule] = get_in(config, ["commands", "bar", "rules"])
    assert String.starts_with?(rule, "when command is foo:bar")
  end

  test "errors when permissions don't match rules" do
    rules = ["when command is foo:date must have foo:view"]
    config = put_in(minimal_config, ["commands", "date", "rules"], rules)
    response = validate(config)

    assert response == {:error, [{"The permission 'foo:view' is not in the list of permissions.", "#/commands/date/rules/0"}]}
  end

  test "errors on bad rule" do
    rules = ["when command is foo:bar must have permission == foo:baz"]
    config = put_in(minimal_config, ["commands", "date", "rules"], rules)

    response = validate(config)

    assert response == {:error, [{"(Line: 1, Col: 34) References to permissions must be the literal \"allow\" or start with a command bundle name or \"site\".", "#/commands/date/rules/0"}]}
  end

  test "errors on bad command option type" do
    options = %{"option_1" => %{"type" => "integer", "required" => false}}
    config = put_in(minimal_config, ["commands", "date", "options"], options)
    response = validate(config)

    assert response == {:error, [{"Value \"integer\" is not allowed in enum.", "#/commands/date/options/option_1/type"}]}
  end

  test "errors on bad template format" do
    templates = %{"foo" => "Some template"}
    config = put_in(minimal_config, ["templates"], templates)
    response = validate(config)

    assert response == {:error, [{"Type mismatch. Expected Object but got String.", "#/templates/foo"}]}
  end

  test "errors on bad template adapter" do
    templates = %{"foo" => %{"meh" => "{{content}}"}}
    config = put_in(minimal_config, ["templates"], templates)
    response = validate(config)

    assert response == {:error, [{"Schema does not allow additional properties.", "#/templates/foo/meh"}]}
  end

  # env_vars can be strings, booleans and numbers
  Enum.each(["string", true, 4], fn(type) ->
    test "env_vars can be a #{type}" do
      env_var = %{"env1" => unquote(type)}
      config = put_in(minimal_config, ["commands", "date", "env_vars"], env_var)

      response = validate(config)
      assert response == :ok
    end
  end)

end
