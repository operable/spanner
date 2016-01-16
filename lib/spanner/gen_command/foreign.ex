defmodule Spanner.GenCommand.Foreign do
  @moduledoc """

  Cog provides a pristine environment to the executable that is called, with only `USER`, `HOME`, and `LANG`
  allowed to leak from Cog's environment. Additional environment variables may also be set in the Cog
  configuration file for inclusion in the execution environment. If any of the pass-through variables are set
  in the configuration file, those values override the inherited values from Cog's environment.

  In addition, there are a number of Cog-specific variables that are provided for all commands:

  ### Arguments

  * COG_ARGC=3
  * COG_ARGV_0="foo"
  * COG_ARGV_1="bar"
  * COG_ARGV_2="baz"

  ### Options

  * COG_OPTS="verbose,force,id"
  * COG_OPT_VERBOSE="true"
  * COG_OPT_FORCE="true"
  * COG_OPT_ID="123"

  ### Other Variables

  * COG_BUNDLE="operable"
  * COG_COMMAND="my_script"
  * COG_USER="imbriaco"
  * COG_INVOCATION="my_script --verbose --force --id=123 foo bar baz"
  * COG_PIPELINE_ID="374643c4-3f48-4e60-8c4f-671e3a11c06b"
  """

  @behaviour Spanner.GenCommand

  defstruct [:bundle, :command, :executable,
             :executable_args, :env_overlays, :runner_script]

  def init(args, _service_proxy) do
    {:ok, %__MODULE__{bundle:  Keyword.fetch!(args, :bundle),
                      command: Keyword.fetch!(args, :command),
                      executable: Keyword.fetch!(args, :executable),
                      executable_args: Keyword.get(args, :executable_args, []),
                      runner_script: runner_script_path()}}
  end

  def handle_message(_request, _state) do
  end

  defp runner_script_path() do
    script = Path.join([Application.app_dir(:spanner, "priv/scripts"), "invoke.sh"])
    cond do
      File.regular?(script) ->
        script
      true ->
        raise RuntimeError, "Foreign command invoke script '#{script}' is missing"
    end
  end

end
