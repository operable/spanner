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
  * COG_PIPELINE_ID="374643c4-3f48-4e60-8c4f-671e3a11c06b"
  """

  @behaviour Spanner.GenCommand

  # Do not inherit existing environment and start a restricted
  # interactive shell
  @foreign_shell "/usr/bin/env"
  @foreign_shell_args ["-i", "/bin/sh", "-i"]
  @output_timeout 1000

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

  def handle_message(request, %__MODULE__{executable: exe, base_env: base}=state) do
    IO.puts "#{inspect request}"
    proc = start_process(base)
    try do
      # TODO Apply overlays
      calling_env = build_calling_env(request, state)
      IO.puts "#{inspect calling_env}"
      apply_vars(proc, calling_env)
      Proc.send_input(proc, "#{exe}\n")
      {out, err} = read_output(proc.pid)
      Proc.await(proc, 10)
      if err != "" do
        {:reply, request.reply_to, err, state}
      else
        {:reply, request.reply_to, out, state}
      end
    after
      Proc.stop(proc)
    end
  end

  defp read_output(pid) do
    read_output(pid, @output_timeout, "", "")
  end

  defp read_output(pid, output_timeout, out, err) do
    receive do
      {^pid, :data, :err, data} ->
        err = err <> data
        if err == "sh: no job control in this shell" do
          read_output(pid, 5, out, "")
        else
          read_output(pid, 5, out, err)
        end
      {^pid, :data, :out, data} ->
        read_output(pid, 5, out <> data, err)
    after output_timeout ->
        {out, err}
    end
  end

  defp drain(proc) do
    pid = proc.pid
    receive do
      {^pid, :data, _, _} ->
        drain(proc)
    after 0 ->
        :ok
    end
  end

  defp inspect_base_environment do
    user_env = System.get_env("USER")
    home_env = System.get_env("HOME")
    lang_env = System.get_env("LANG")
    %{"USER" => user_env,
      "HOME" => home_env,
      "LANG" => lang_env}
  end

  defp start_process(base_vars) do
    proc = Porcelain.spawn(@foreign_shell, @foreign_shell_args,
                         in: :receive, out: {:send, self()})
    apply_vars(proc, base_vars)
  end

  defp apply_vars(proc, vars) do
    Enum.each(vars, &set_env(proc, &1))
    drain(proc)
    proc
  end

  defp set_env(proc, {name, value}) when is_atom(name) do
    set_env(proc, {Atom.to_string(name), value})
  end
  defp set_env(proc, {name, value}) when is_binary(name) do
    name = String.upcase(name)
    value = "#{value}"
    Proc.send_input(proc, "export #{name}=#{value} >& /dev/null\n")
  end

  defp build_calling_env(request, %__MODULE__{bundle: bundle, command: command}) do
    %{"COG_BUNDLE" => bundle,
      "COG_COMMAND" => command,
      "COG_USER" => request.requestor["handle"]}
    |> Map.merge(build_args_vars(request.args))
    |> Map.merge(build_options_vars(request.options))
  end

  defp build_args_vars([]) do
    %{"COG_ARGC" => "0"}
  end
  defp build_args_vars(args) do
    acc = %{"COG_ARGC" => Integer.to_string(length(args))}
    Enum.reduce(Enum.with_index(args, 1), acc,
      fn({value, index}, acc) ->
        Map.put(acc, "COG_ARGV_#{index}", "#{value}")
      end)
  end

  defp build_options_vars(options) do
    opt_names = Enum.join(Map.keys(options), ",")
    acc = %{"COG_OPTS" => "\"#{opt_names}\""}
    Enum.reduce(options, acc,
      fn({key, value}, acc) ->
        Map.put(acc, "COG_OPT_#{key}", "#{value}")
      end)
  end

end
