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

  defmodule NeitherCommandNorService do
    def howdy, do: "Hello World"
  end

  test "creates a config for a set of modules" do
    config = Config.gen_config("testing", [CommandWithoutOptions,
                                           CommandWithOptions,
                                           UnenforcedCommand,
                                           UnboundCommand,
                                           NeitherCommandNorService], ".")
    assert %{"bundle" => %{"name" => "testing"},
             "commands" => [%{"name" => "command-without-options",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "enforcing" => true,
                              "calling_convention" => :bound,
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.CommandWithoutOptions"},
                            %{"name" => "command-with-options",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "enforcing" => true,
                              "calling_convention" => :bound,
                              "options" => [%{"name" => "option_1",
                                              "type" => "bool",
                                              "required" => true}],
                              "module" => "Spanner.Bundle.Config.Test.CommandWithOptions"},
                            %{"name" => "unenforced-command",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "enforcing" => false,
                              "calling_convention" => :bound,
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.UnenforcedCommand"},
                            %{"name" => "unbound-command",
                              "documentation" => nil,
                              "version" => "0.0.1",
                              "enforcing" => false,
                              "calling_convention" => :all,
                              "options" => [],
                              "module" => "Spanner.Bundle.Config.Test.UnboundCommand"}],
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
    config = Config.gen_config("testing", [], "test/support/test-bundle")

    assert %{"templates" => [%{"adapter" => "hipchat",
                               "name" => "help",
                               "path" => "templates/hipchat/help.mustache",
                               "source" => """
                               {{#command}}
                                 Documentation for <pre>{{command}}</pre>
                                 {{{documentation}}}
                               {{/command}}
                               """},
                             %{"adapter" => "slack",
                               "name" => "help",
                               "path" => "templates/slack/help.mustache",
                               "source" => """
                               {{#command}}
                                 Documentation for `{{command}}`
                                 {{{documentation}}}
                               {{/command}}
                               """}]} = config
  end
end
