defmodule Spanner.GenCommand.Foreign.ErrorHandler do

  @behaviour :gen_fsm

  alias Porcelain.Process, as: Proc

  defstruct [:proc, :line, :lines, :pending]

  defmacrop next_state(current, next, state) do
    quote do
      {:next_state, unquote(next), unquote(state)}
    end
  end

  defmacrop next_state(current, next, reply, state) do
    quote do
      {:reply, unquote(reply), unquote(next), unquote(state)}
    end
  end


  def start_link() do
    :gen_fsm.start_link(__MODULE__, [], [])
  end

  def prepare(pid, proc) do
    :gen_fsm.sync_send_event(pid, {:prepare, proc})
  end

  def get_errors(pid) do
    :gen_fsm.sync_send_event(pid, :get_errors)
  end

  def init([]) do
    {:ok, :ready, %__MODULE__{}}
  end

  def ready({:prepare, proc}, _from, state) do
    next_state(:ready, :prepared, :ok, %{state | proc: proc, line: "", lines: []})
  end
  def ready(:get_errors, _from, state) do
    next_state(:ready, :ready, "", state)
  end

  def prepared(:get_errors, from, state) do
    next_state(:prepared, :prepared, %{state | pending: from})
  end

  def handle_event(_event, current_state, state) do
    next_state(current_state, current_state, state)
  end

  def handle_sync_event(_event, _from, current_state, state) do
    {:reply, :ignore, current_state, state}
  end

  def handle_info({_, :data, :err, err}, :prepared, %__MODULE__{proc: proc, line: line, lines: lines}=state) do
    text = line <> err
    if line?(text) do
      text = String.strip(text)
      cond do
        String.match?(text, ~r/exit/) ->
          if state.pending != nil do
            :gen_fsm.reply(state.pending, "")
          end
          wait_for_proc(proc)
          next_state(:prepared, :ready, %{state | line: "", lines: [], pending: nil})
        # Ignoreable output
        String.match?(text, ~r/(^sh:|^sh-)/) ->
          next_state(:prepared, :prepared, %{state | line: ""})
        true ->
          Proc.send_input(proc, "\n")
          next_state(:prepared, :reading, %{state | line: "", lines: [text|lines]})
      end
    else
      next_state(:prepared, :prepared, %{state | line: text})
    end
  end
  def handle_info({_, :data, :err, err}, :reading, %__MODULE__{proc: proc, line: line, lines: lines, pending: pending}=state) do
    text = line <> err
    cond do
      # Shell processed the newline sent above
      String.match?(text, ~r/^sh(\:|\-)/) ->
        if pending != nil do
          :gen_fsm.reply(pending, Enum.join(Enum.reverse(lines), "\n"))
        end
        Proc.send_input(proc, "exit\n")
        next_state(:reading, :cleanup, %{state | line: "", lines: [], pending: nil})
      true ->
        next_state(:reading, :reading, %{state | line: "", lines: [text|lines]})
    end
  end
  def handle_info({_, :data, :err, err}, :cleanup, %__MODULE__{proc: proc, line: line}=state) do
    text = line <> err
    if String.match?(text, ~r/exit/) do
      wait_for_proc(proc)
      next_state(:cleanup, :ready, %{state | proc: nil, line: ""})
    else
      next_state(:cleanup, :cleanup, %{state | line: text})
    end
  end
  def handle_info(_info, current_state, state) do
    {:next_state, current_state, state}
  end

  def code_change(_oldvsn, current_state, state, _extra) do
    {:ok, current_state, state}
  end

  def terminate(_current_state, _reason, _state) do
    :ok
  end

  defp line?(text), do: String.ends_with?(text, "\n")

  defp wait_for_proc(proc) do
    Proc.await(proc, 10)
    Proc.stop(proc)
  end

end
