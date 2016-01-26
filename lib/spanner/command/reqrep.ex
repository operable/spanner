defmodule Spanner.Command.Request do

  use Spanner.Marshalled
  require Logger

  @command_config_root "relay/command_config"

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
      true ->
        {:ok, %{request | command_config: populate_config(request)}}
    end
  end

  defp populate_config(request) do
    case read_config(request) do
      {:ok, ""} ->
        Logger.info("The config file for command: #{request.command} is empty")
        %{}
      {:ok, config} ->
        Poison.decode!(config)
      _ ->
        Logger.warn("There was a problem accessing the config file for command: #{request.command}")
        %{}
    end
  end

  defp read_config(request) do
    config_dir = Path.join(Path.rootname(File.cwd!, "cog"), @command_config_root)
    [ns, _cmd] = String.split(request.command, ":")
    File.open(Path.join([config_dir, ns, "config.json"]), [:read], fn(file) ->
      IO.read(file, :all)
    end)
  end
end

defmodule Spanner.Command.Response do

  use Spanner.Marshalled

  defmarshalled [:room, :status, :status_message, :body, :bundle, :template]

end
