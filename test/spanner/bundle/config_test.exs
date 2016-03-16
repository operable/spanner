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

  defmodule UnenforcedCommand do
    use GenCommand.Base, name: "unenforced-command", enforcing: false, bundle: "testing"

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule UnboundCommand do
    use GenCommand.Base, name: "unbound-command", enforcing: false, bundle: "testing", calling_convention: :all

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule ExecutionOnceCommand do
    use GenCommand.Base, name: "execution-once-command", enforcing: false, bundle: "testing", execution: :once

    def handle_message(_,_), do: {:reply, "blah", "blah", "blah"}
  end

  defmodule NeitherCommandNorService do
    def howdy, do: "Hello World"
  end

  test "creates a config for a set of modules" do
    config = Config.gen_config("testing", [CommandWithoutOptions,
                                           CommandWithOptions,
                                           UnenforcedCommand,
                                           UnboundCommand,
                                           ExecutionOnceCommand,
                                           NeitherCommandNorService], ".")
    assert %{"bundle" => %{"name" => "testing",
                           "type" => "elixir"},
             "commands" => [%{"name" => "command-without-options",
                              "documentation" => nil,
                              "enforcing" => true,
                              "calling_convention" => "bound",
                              "execution" => "multiple",
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.CommandWithoutOptions"},
                            %{"name" => "command-with-options",
                              "documentation" => nil,
                              "enforcing" => true,
                              "calling_convention" => "bound",
                              "execution" => "multiple",
                              "options" => [%{"name" => "option_1",
                                              "type" => "bool",
                                              "required" => true}],
                              "module" => "Spanner.Bundle.Config.Test.CommandWithOptions"},
                            %{"name" => "unenforced-command",
                              "documentation" => nil,
                              "enforcing" => false,
                              "calling_convention" => "bound",
                              "execution" => "multiple",
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.UnenforcedCommand"},
                            %{"name" => "unbound-command",
                              "documentation" => nil,
                              "enforcing" => false,
                              "calling_convention" => "all",
                              "execution" => "multiple",
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.UnboundCommand"},
                            %{"name" => "execution-once-command",
                              "documentation" => nil,
                              "enforcing" => false,
                              "calling_convention" => "bound",
                              "execution" => "once",
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.ExecutionOnceCommand"}],
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
    config = Config.gen_config("testing", [NeitherCommandNorService], ".")
    assert %{"bundle" => %{"name" => "testing", "type" => "elixir"},
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
    config = Config.gen_config("testing", [], "test/support/test-bundle")

    assert %{"templates" => [%{"adapter" => "hipchat",
                               "name" => "help",
                               "path" => "test/support/test-bundle/templates/hipchat/help.mustache",
                              },
                             %{"adapter" => "slack",
                               "name" => "help",
                               "path" => "test/support/test-bundle/templates/slack/help.mustache",
                               }]} = config
  end
end
