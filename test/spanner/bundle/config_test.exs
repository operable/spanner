defmodule Spanner.Bundle.Config.Test do
  use ExUnit.Case, async: true
  alias Spanner.Bundle.Config
  alias Spanner.GenCommand

  # Create some test modules; these will be our "bundle"

  defmodule CommandWithoutOptions do
    use GenCommand.Base, name: "command-without-options", bundle: "testing"

    permission "foo"
    rule "when command is testing:command-without-options must have testing:foo"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule CommandWithOptions do
    use GenCommand.Base, name: "command-with-options", bundle: "testing"

    option "option_1", type: "bool", required: true
    permission "bar"
    permission "baz"

    rule "when command is testing:command-with-options must have testing:bar"
    rule "when command is testing:command-with-options with arg[0] == 'baz' must have testing:baz"
    def handle_message(_,_), do: {:reply, "blah", "blah", :blah}
  end

  defmodule PrimitiveCommand do
    use GenCommand.Base, name: "primitive-command", primitive: true, bundle: "testing"

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule NeitherCommandNorService do
    def howdy, do: "Hello World"
  end

  test "creates a config for a set of modules" do
    config = Config.gen_config("testing", [CommandWithoutOptions,
                                           CommandWithOptions,
                                           PrimitiveCommand,
                                           NeitherCommandNorService], [])
    assert %{"bundle" => %{"name" => "testing"},
             "commands" => [%{"name" => "command-without-options",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "primitive" => false,
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.CommandWithoutOptions"},
                            %{"name" => "command-with-options",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "primitive" => false,
                              "options" => [%{"name" => "option_1",
                                              "type" => "bool",
                                              "required" => true}],
                              "module" => "Spanner.Bundle.Config.Test.CommandWithOptions"},
                            %{"name" => "primitive-command",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "primitive" => true,
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.PrimitiveCommand"}],
             "permissions" => ["testing:bar", "testing:baz", "testing:foo"],
             "rules" => [
               "when command is testing:command-with-options must have testing:bar",
               "when command is testing:command-with-options with arg[0] == 'baz' must have testing:baz",
               "when command is testing:command-without-options must have testing:foo"
             ],
             "templates" => []} == config
  end

  # TODO: Should this be allowed?
  test "creates a config when there are no commands, services, permissions, or rules" do
    config = Config.gen_config("testing", [NeitherCommandNorService], [])
    assert %{"bundle" => %{"name" => "testing"},
             "commands" => [],
             "permissions" => [],
             "rules" => [],
             "templates" => []} == config
  end

  @config %{"commands" => [%{"module" => "Elixir.AWS.Commands.Describe"},
                           %{"module" => "Elixir.AWS.Commands.Tag"}]}

  test "finding command beam files from manifest" do
    assert [
      {AWS.Commands.Describe, []},
      {AWS.Commands.Tag, []}
    ] = Config.commands(@config)
  end

  test "includes templates in the config" do
    config = Config.gen_config("testing", [], ["templates/slack/foo.mustache",
                                               "templates/slack/bar.mustache",
                                               "templates/hipchat/foo.mustache"])

    assert %{"templates" => [%{"name" => "foo",
                               "adapter" => "slack",
                               "path" => "templates/slack/foo.mustache"},
                             %{"name" => "bar",
                               "adapter" => "slack",
                               "path" => "templates/slack/bar.mustache"},
                             %{"name" => "foo",
                               "adapter" => "hipchat",
                               "path" => "templates/hipchat/foo.mustache"}]} = config
  end
end
