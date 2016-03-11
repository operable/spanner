defmodule Spanner.Command.Request do

  use Spanner.Marshalled
  alias Spanner.Config

  require Logger

  defmarshalled [:room, :requestor, :command, :args, :options, :command_config, :reply_to, :cog_env]

  defp validate(request) do
    cond do
      request.room == nil ->
        {:error, {:empty_field, :room}}
      request.requestor == nil ->
        {:error, {:empty_field, :requestor}}
      request.command == nil ->
        {:error, {:empty_field, :command}}
      request.reply_to == nil ->
        {:error, {:empty_field, :reply_to}}
      true -> populate_config(request)
    end
  end

  defp populate_config(request) do
    case get_config(request) do
      {:ok, command_config} -> {:ok, %{request | command_config: command_config}}
      error -> error
    end
  end

  defp get_config(request) do
    case open_config(request) do
      {:ok, ""} -> {:ok, %{}}
      {:ok, config} -> {:ok, config}
      {:error, error} ->
        err = "Unable to read the command config file '#{Config.dynamic_file_name}' for the command '#{request.command}'. #{inspect error}"
        Logger.error(err)
        {:error, err}
    end
  end

  defp open_config(request) do
    case Application.get_env(:spanner, :command_config_root) do
      nil -> {:ok, ""}
      path -> read_config(request, path)
    end
  end

  defp read_config(request, config_path) do
    [bundle, _cmd] = String.split(request.command, ":", parts: 2)
    cmd_config_file = Path.join([config_path, bundle, Config.dynamic_file_name()])
    case File.exists?(cmd_config_file) do
      true ->
        Config.Parser.read_from_file(cmd_config_file)
      false -> {:ok, ""}
    end
  end

end

defmodule Spanner.Command.Response do

  use Spanner.Marshalled

  defmarshalled [:room, :status, :status_message, :body, :bundle, :template]

end
