defmodule Spanner.Config.V4ValidatorTest do
  # This is effectively the same as the v3 validator test, but with
  # altered template tests, since that's the only difference between
  # the two versions.

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
    %{"cog_bundle_version" => 4,
      "name" => "foo",
      "version" => "0.0.1",
      "description" => "Does some foo and a bar",
      "commands" => %{
        "date" => %{
          "executable" => "/bin/date",
          "rules" => [
            "allow"
          ]
        }
      }
    }
  end

  defp incomplete_rules_config do
    %{"cog_bundle_version" => 4,
      "name" => "foo",
      "version" => "0.1",
      "description" => "Does some foo and a bar",
      "permissions" => ["foo:view"],
      "commands" => %{
        "bar" => %{"executable" => "/bin/bar",
                   "rules" => ["must have foo:view"]},
        "baz" => %{"executable" => "/bin/baz",
                   "rules" => ["allow"]}}}
  end

  test "minimal config" do
    assert validate(minimal_config) == :ok
  end

  test "bad bundle versions" do
    updated = put_in(minimal_config, ["version"], "1")
    assert validate(updated) == {:error, [{"String \"1\" does not match pattern \"^\\\\d+\\\\.\\\\d+($|\\\\.\\\\d+$)\".", "#/version"}], []}
    updated = put_in(minimal_config, ["version"], "0.0.1-beta")
    assert validate(updated) == {:error, [{"String \"0.0.1-beta\" does not match pattern \"^\\\\d+\\\\.\\\\d+($|\\\\.\\\\d+$)\".", "#/version"}], []}
  end

  test "wrong cog_bundle_version" do
    result = update_in(minimal_config, ["cog_bundle_version"], fn(_) -> 1 end)
    |> validate
    assert result == {:error, [{"cog_bundle_version 1 is not supported. Please update your bundle config to version 4.", "#/cog_bundle_version"}], []}
  end

  test "missing cog_bundle_version" do
    result = Map.delete(minimal_config, "cog_bundle_version") |> validate
    assert result == {:error, [{"cog_bundle_version not specified. You must specify a valid bundle version. The current version is 4.", "#/cog_bundle_version"}], []}
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

    assert response == {:error, [{"The permission 'foo:view' is not in the list of permissions.", "#/commands/date/rules/0"}], []}
  end

  test "errors on bad rule" do
    rules = ["when command is foo:bar must have permission == foo:baz"]
    config = put_in(minimal_config, ["commands", "date", "rules"], rules)

    response = validate(config)

    assert response == {:error, [{"(Line: 1, Col: 34) References to permissions must be the literal \"allow\" or start with a command bundle name or \"site\".", "#/commands/date/rules/0"}], []}
  end

  test "rules are required" do
    config = update_in(minimal_config, ["commands", "date"], &Map.delete(&1, "rules"))
    |> validate
    assert config == {:error, [{"Required property rules was not present.", "#/commands/date"}], []}
  end

  test "errors on bad command option type" do
    options = %{"option_1" => %{"type" => "integer", "required" => false}}
    config = put_in(minimal_config, ["commands", "date", "options"], options)
    response = validate(config)

    assert response == {:error, [{"Value \"integer\" is not allowed in enum.", "#/commands/date/options/option_1/type"}], []}
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

  ########################################################################
  # Templates

  test "templates are validated" do
    templates = %{"blah" => %{"body" => "blahblah"},
                  "foo" => %{"body" => "foofoo"}}
    config = put_in(minimal_config, ["templates"], templates)
    assert :ok == validate(config)
  end

  test "errors on bad template format" do
    templates = %{"foo" => "Some template"}
    config = put_in(minimal_config, ["templates"], templates)
    response = validate(config)
    assert {:error, [{"Type mismatch. Expected Object but got String.", "#/templates/foo"}], []} == response
  end

  test "templates must have proper names" do
    templates = %{"1?" => %{"body" => "Some template"}}
    config = put_in(minimal_config, ["templates"], templates)
    response = validate(config)

    # Not the greatest error message for this, sadly :(
    assert response == {:error, [{"Schema does not allow additional properties.", "#/templates/1?"}], []}
  end

end
