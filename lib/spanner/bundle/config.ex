defmodule Spanner.Bundle.Config do
  @moduledoc """
  Interact with and generate bundle configurations.

  A bundle configuration is a map that contains the following information:

  - The bundle name
  - A list of all commands in the bundle, including the command's
    invocation name, the Elixir module that implements it, the various
    options the command may take, and the command's version
  - A list of permissions the bundle will create
  - A list of initial rules for the commands in the bundle, using the
    bundle permissions.

  ## Example

      %{bundle: %{name: "foo"},
        commands: [%{module: "Spanner.Commands.AddRule",
                     name: "add-rule",
                     options: [],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Admin",
                     name: "admin",
                     options: [%{name: "add", required: false, type: "bool"},
                               %{name: "list", required: false, type: "bool"},
                               %{name: "drop", required: false, type: "bool"},
                               %{name: "id", required: false, type: "string"},
                               %{name: "arg0", required: false, type: "string"},
                               %{name: "permission", required: false, type: "string"},
                               %{name: "for-command", required: false, type: "string"}],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Builds",
                     name: "builds",
                     options: [%{name: "state", required: true, type: "string"}],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Echo",
                     name: "echo",
                     options: [],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Giphy",
                     name: "giphy",
                     options: [],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Grant",
                     name: "grant",
                     options: [%{name: "command", required: true, type: "string"},
                               %{name: "permission", required: true, type: "string"},
                               %{name: "to", required: true, type: "string"}], version: "0.0.1"},
                   %{module: "Spanner.Commands.Greet",
                     name: "greet",
                     options: [],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Math",
                     name: "math",
                     options: [],
                     version: "0.0.1"},
                   %{module: "Spanner.Commands.Stackoverflow",
                     name: "stackoverflow",
                     options: [],
                     version: "0.0.1"},
        permissions: ["foo:admin", "foo:read", "foo:write"],
        rules: ["when command is foo:add-rule must have foo:admin",
                "when command is foo:grant must have foo:admin"]}

  """

  # TODO: Worthwhile creating structs for this?

  require Logger
  alias Spanner.GenCommand

  def commands(config), do: process_args(config, "commands")

  # TODO: Scope these to avoid conflicts with pre-existing modules
  # TODO: Pass each command process config from the bundle config
  def process_args(bundle_config, "commands") do
    for config <- Map.get(bundle_config, "commands", []) do
      case config do
        %{"module" => module_name} ->
          {Module.safe_concat("Elixir", module_name), []}
        %{"name" => name, "executable" => executable} ->
          %{"bundle" => %{"name" => bundle}} = bundle_config
          {Spanner.Command.ForeignCommand, [[bundle: bundle, name: name, executable: executable]]}
      end
    end
  end

  def modules(config, type) do
    for %{"module" => module_name} <- Map.get(config, type, []),
      do: Module.safe_concat("Elixir", module_name)
  end

  @doc """
  Generate a bundle configuration via code introspection. Returns a
  map representing the configuration, ready for turning into JSON.

  ## Arguments

  - `name`: the name of the bundle
  - `modules`: a list of modules to be included in the bundle

  """
  def gen_config(name, modules, work_dir) do
    # We create single key/value pair maps for each
    # top-level key in the overall configuration, and then merge all
    # those maps together.
    Enum.reduce([gen_bundle(name),
                 gen_commands(modules),
                 gen_permissions(name, modules),
                 gen_rules(modules),
                 gen_templates(work_dir)],
                &Map.merge/2)
  end

  # Generate top-level bundle configuration
  defp gen_bundle(name) do
    %{"bundle" => %{"name" => name}}
  end

  # Generate the union of all permissions required by commands in the
  # bundle. Returned permissions are namespaced by the bundle name.
  defp gen_permissions(bundle_name, modules) do
    permissions = modules
    |> only_commands
    |> Enum.map(&(&1.permissions))
    |> Enum.map(&Enum.into(&1, HashSet.new))
    |> Enum.reduce(HashSet.new, &Set.union/2)
    |> Enum.map(&namespace_permission(bundle_name, &1))
    |> Enum.sort

    %{"permissions" => permissions}
  end

  defp namespace_permission(bundle_name, permission_name),
    do: "#{bundle_name}:#{permission_name}"

  # Extract rules from all commands in the bundle
  defp gen_rules(modules) do
    rules = modules
    |> only_commands
    |> Enum.flat_map(&(&1.rules))
    |> Enum.sort

    %{"rules" => rules}
  end

  defp gen_templates(work_dir) do
    paths = Path.wildcard("#{work_dir}/templates/*/*.mustache")

    templates = for path <- paths do
      relative_path = Path.relative_to(path, work_dir)
      ["templates", adapter, file] = Path.split(relative_path)
      name = Path.basename(file, ".mustache")
      source = File.read!(path)

      %{"adapter" => adapter,
        "name" => name,
        "path" => relative_path,
        "source" => source}
    end

    %{"templates" => templates}
  end

  # Extract all commands from `modules` and generate configuration
  # maps for them
  defp gen_commands(modules) do
    %{"commands" => Enum.map(only_commands(modules), &command_map/1)}
  end

  defp only_commands(modules),
    do: Enum.filter(modules, &GenCommand.is_command?/1)

  defp command_map(module) do
    modattrs = module.module_info(:attributes)
    %{"name" => fetch_attribute!(modattrs, :command_name),
      "enforcing" => fetch_attribute!(modattrs, :enforcing),
      "version" => get_attribute(modattrs, :command_version, "0.0.1"),
      "options" => Keyword.get(modattrs, :options, []),
      "documentation" => case Code.get_docs(module, :moduledoc) do
                           {_line, doc} ->
                             # If a module doesn't have a module doc,
                             # then it'll return a tuple of `{1, nil}`,
                             # so that works out fine here.
                             doc
                           nil ->
                             # TODO: Transition away from @moduledoc
                             # to our own thing; modules defined in
                             # test scripts apparently can access
                             # @moduledocs
                             nil
                         end,
        "module" => inspect(module)}
  end

  defp get_attribute(modattrs, key, default) do
    case Keyword.get(modattrs, key, default) do
      ^default ->
        default
      [value] ->
        value
      values ->
        values
    end
  end

  defp fetch_attribute!(modattrs, key) do
    case Keyword.fetch!(modattrs, key) do
      [value] ->
        value
      values ->
        values
    end
  end

end
