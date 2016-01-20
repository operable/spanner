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

  # Do not inherit existing environment and start a restricted
  # interactive shell
  @foreign_shell "/usr/bin/env -i /bin/sh -i -r"

  defstruct [:bundle, :command, :executable,
             :executable_args, :base_env, :env_overlays]

  alias Porcelain.Process, as: Proc

  def init(args, _service_proxy) do
    {:ok, %__MODULE__{bundle:  Keyword.fetch!(args, :bundle),
                      command: Keyword.fetch!(args, :command),
                      executable: Keyword.fetch!(args, :executable),
                      base_env: inspect_base_environment(),
                      env_overlays: Keyword.get(args, :env, []),
                      executable_args: Keyword.get(args, :executable_args, [])}}
  end

  def handle_message(request, %__MODULE__{base_env: base}=state) do
    IO.puts request.reply_to
    proc = start_process(base)
    try do
      # Apply overlays
      # Set request env vars
      # Call executable w/args
      # Read response
    after
      Proc.stop(proc)
      # Send command response
      {:reply, "ok", state}
    end
  end

  defp inspect_base_environment do
    user_env = System.get_env("USER")
    home_env = System.get_env("HOME")
    lang_env = System.get_env("LANG")
    %{"USER" => user_env, "HOME" => home_env, "LANG" => lang_env}
  end

  defp start_process(base_vars) do
    proc = Porcelain.spawn_shell(@foreign_shell, in: :receive, out: {:send, self()},
                                 err: {:send, self()})
    apply_vars(proc, base_vars)
  end

  defp apply_vars(proc, vars) do
    Enum.each(vars, &set_env(proc, &1))
    proc
  end

  defp set_env(proc, {name, value}) when is_atom(name) do
    set_env(proc, {Atom.to_string(name), value})
  end
  defp set_env(proc, {name, value}) when is_binary(name) do
    name = String.upcase(name)
    value = "#{value}"
    Proc.send_input(proc, "export #{name}=#{value}\n")
  end

end
