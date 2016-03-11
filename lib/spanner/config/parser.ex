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
      yaml = YamlElixir.read_from_file(path)
      # We should never get an empty map back from 'YamlElixir.read_from_file/1'.
      # If we do, we return an error.
      if length(Map.values(yaml)) == 0 do
        {:error, ["Parsing '#{path}' returned an empty map. Check the file for syntax errors such as missing closing brackets."]}
      else
        {:ok, yaml}
      end
    catch
      {:yamerl_exception, errors} ->
        {:error, Enum.map(errors, &format_errors/1)}
    end
  end

  @doc """
  Reads YAML from a string. The underlying lib, yamerl, throws when
  errors occur. We catch those and return tuple containing the atom ':error'
  and the list error messages.
  """
  def read_from_string(str) do
    try do
      yaml = YamlElixir.read_from_string(str)
      # We should never get an empty map back from 'YamlElixir.read_from_file/1'.
      # If we do, we return an error.
      if length(Map.values(yaml)) == 0 do
        {:error, ["Error parsing config. An empty map was returned. Check the file for syntax errors such as missing closing brackets."]}
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
