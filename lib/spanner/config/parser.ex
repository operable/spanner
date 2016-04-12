defmodule Spanner.Config.Parser do

  @moduledoc """
  Functions for parsing YAML config files
  """

  @doc """
  Reads a YAML file from 'path'. The underlying lib, yamerl, throws when
  errors occur. We catch those and return tuple containing the atom ':error'
  and the list error messages.
  """
  @spec read_from_file(String.t) :: {:ok, Map.t} | {:error, list()}
  def read_from_file(path) do
    try do
      yaml = YamlElixir.read_from_file(path)
      |> Spanner.Config.fixup_rules
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
    rescue
      error ->
        {:error, ["Malformed file: #{inspect error}"]}
    end
  end

  @doc "Same as 'read_from_file/1' except it throws when an error is encountered"
  @spec read_from_file(String.t) :: {:ok, Map.t} | {:error, list()} | no_return()
  def read_from_file!(path) do
    case read_from_file(path) do
      {:ok, yaml} -> yaml
      error -> throw(error)
    end
  end

  @doc """
  Reads YAML from a string. The underlying lib, yamerl, throws when
  errors occur. We catch those and return tuple containing the atom ':error'
  and the list error messages.
  """
  @spec read_from_string(String.t) :: {:ok, Map.t} | {:error, list()}
  def read_from_string(str) do
    try do
      yaml = YamlElixir.read_from_string(str)
      |> Spanner.Config.fixup_rules
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
    rescue
      error -> {:error, ["Malformed string: #{inspect error}"]}
    end
  end

  @doc "Same as 'read_from_string/1' except it throws when an error is encountered."
  @spec read_from_string!(String.t) :: {:ok, Map.t} | {:error, list()} | no_return()
  def read_from_string!(path) do
    case read_from_string(path) do
      {:ok, yaml} -> yaml
      error -> throw(error)
    end
  end

  defp format_errors({_, _, msg, :undefined, :undefined, _, _, _}),
    do: msg
  defp format_errors({_, _, msg, line, column, _, _, _}),
    do: "#{msg} - #{line}:#{column}"
end
