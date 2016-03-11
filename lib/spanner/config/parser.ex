defmodule Spanner.Config.Parser do

  @moduledoc """
  Functions for parsing YAML config files
  """

  @doc """
  Reads a YAML file from 'path'. The underlying lib, yamerl, throws when
  errors occur. We catch those and return tuple containing the atom ':error'
  and the list error messages.
  """
  def read_from_file(path) do
    try do
      {:ok, YamlElixir.read_from_file(path)}
    catch
      {:yamerl_exception, errors} ->
        {:error, Enum.map(errors, &format_errors/1)}
    end
  end

  @doc """
  Reads YAML from a string. The underlying lib, yamerl, throws when
  errors occur. We catch those and return tuple containing the atom ':error'
  and the list error messages.

  note: unlike YamlElixir.read_from_file/1 there are some instances where read_from_string
  will ignore errors and just return an empty map. It appears to be an issue with yamerl,
  the erlang lib. In those cases we return an error.
  """
  def read_from_string(str) do
    try do
      yaml = YamlElixir.read_from_string(str)
      # Sometimes errors caught by 'YamlElixir.read_from_file/1'
      if length(Map.values(yaml)) == 0 do
        {:error, ["Empty map returned. Make sure there are no errors in your YAML."]}
      else
        {:ok, yaml}
      end
    catch
      {:yamerl_exception, errors} ->
        {:error, Enum.map(errors, &format_errors/1)}
    end
  end

  defp format_errors({_, _, msg, :undefined, :undefined, _, _, _}),
    do: msg
  defp format_errors({_, _, msg, line, column, _, _, _}),
    do: "#{msg} - #{line}:#{column}"
end
