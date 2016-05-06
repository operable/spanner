defmodule Spanner.Config.Upgrader do
  alias Spanner.Config.SyntaxValidator

  @moduledoc """
  Attempts to upgrade bundle config to current version.
  """

  @current_version 3
  @upgradable_versions [2]

  @doc """
  When possible upgrades config to the current version. Returns the upgraded
  config and a list of warnings for deprecated config options or an error if
  the upgrade fails.
  """
  @spec upgrade(Map.t) :: {:ok, Map.t, List.t} | {:error, List.t}
  def upgrade(%{"cog_bundle_version" => version}=config) when version in @upgradable_versions do
    deprecation_msg =
      {"""
       Bundle config version #{version} has been deprecated. \
       Please update to version #{@current_version}.\
       """,
       "#/cog_bundle_version"}
    # We run the validator for the old version here. So if the user passes an
    # old version that is also invalid, we don't crash trying to access fields
    # that don't exist.
    case SyntaxValidator.validate(config, version) do
      :ok ->
        do_upgrade(config)
        |> insert_deprecation_msg(deprecation_msg)
      {:error, errors} ->
        {:error, errors, [deprecation_msg]}
    end
  end
  def upgrade(_) do
    {:error, {[], [{"Cog bundle version not supported", "#/cog_bundle_version"}]}}
  end

  defp do_upgrade(config) do
    case execution_once?(config["commands"]) do
      {true, {warnings, errors}} ->
        {:error, errors, warnings}
      {false, warnings} ->
        {enforce_warnings, updated_commands} = update_enforcing(config["commands"])
        updated_config = %{config | "commands" => updated_commands}
        |> Map.put("cog_bundle_version", @current_version)
        {:ok, updated_config, warnings ++ enforce_warnings}
    end
  end

  # Checks to see if the execution field exists in the bundle config. If it
  # does but contains "multiple" we just return a warning. If it contains
  # "once" we return an error.
  defp execution_once?(commands) do
    {warnings, errors} = Enum.reduce(commands, {[],[]},
      fn
        ({cmd_name, cmd}, {warnings, errors}) ->
          case Map.get(cmd, "execution", nil) do
            "once" ->
              msg = "Execution 'once' commands are no longer supported"
              location = "#/commands/#{cmd_name}/execution"
              updated_errors = [{msg, location} | errors]
              {warnings, updated_errors}
            "multiple" ->
              msg = "Execution type has been deprecated. Please update your bundle config"
              location = "#/commands/#{cmd_name}/execution"
              updated_warnings = [{msg, location} | warnings]
              {updated_warnings, errors}
            nil ->
              {warnings, errors}
          end
      end)

    if length(errors) > 0 do
      {true, {warnings, errors}}
    else
      {false, warnings}
    end

  end

  # Updates for non enforcing commands. If 'enforcing: false' is specified we
  # add the "allow" rule, delete the enforcing field and return a warning. If
  # 'enforcing: true' is specified we return a warning and delete the field.
  defp update_enforcing(commands) do
    Enum.reduce(commands, {[], commands},
      fn
        ({cmd_name, %{"enforcing" => enforcing}=cmd}, {warnings, commands}) when not(enforcing) ->
          msg = "Non-enforcing commands have been deprecated. Please update your bundle config"
          updated_warnings = [{msg, "#/commands/#{cmd_name}/enforcing"} | warnings]

          updated_cmd = Map.put(cmd, "rules", ["allow"])
          |> Map.delete("enforcing")
          updated_commands = Map.put(commands, cmd_name, updated_cmd)

          {updated_warnings, updated_commands}
        ({cmd_name, %{"enforcing" => _}=cmd}, {warnings, commands}) ->
          msg = "The 'enforcing' field has been deprecated. Please update your bundle config"
          updated_warnings = [{msg, "#/commands/#{cmd_name}/enforcing"} | warnings]

          updated_cmd = Map.delete(cmd, "enforcing")
          updated_commands = Map.put(commands, cmd_name, updated_cmd)

          {updated_warnings, updated_commands}
        (_, acc) ->
          acc
      end)
  end

  defp insert_deprecation_msg({status, errors, warnings}, msg) do
    {status, errors, [msg | warnings]}
  end
end
