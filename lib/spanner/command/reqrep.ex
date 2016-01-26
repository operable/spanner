defmodule Spanner.Command.Request do

  use Spanner.Marshalled

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
      {:ok, ""} ->
        Logger.info("The config file for command: #{request.command} is empty")
        {:ok, %{}}
      {:ok, config} ->
        case Poison.decode(config) do
          {:ok, cmd_config} -> {:ok, cmd_config}
          {:error, error} ->
            err = "Please verify the command config file for '#{request.command}' is in valid json format. #{inspect error}"
            Logger.error(err)
            {:error, err}
        end
      {:error, error} ->
        err = "Unable to read the command config file 'config.json' for the command '#{request.command}'. #{inspect error}"
        Logger.error(err)
        {:error, err}
    end
  end

  defp open_config(request) do
    config_path = Application.get_env(:cog, :command_config_root)
    case config_path do
      nil -> {:error, "Please set environment variable 'COG_COMMAND_CONFIG_ROOT' to a valid location and ensure that the necessary command config files exists in that location."}
      _ -> read_config(request, config_path)
    end
  end

  defp read_config(request, config_path) do
    [ns, _cmd] = String.split(request.command, ":")
    File.open(Path.join([config_path, ns, "config.json"]), [:read], fn(file) ->
      IO.read(file, :all)
    end)
  end

end

defmodule Spanner.Command.Response do

  use Spanner.Marshalled

  defmarshalled [:room, :status, :status_message, :body, :bundle, :template]

end
