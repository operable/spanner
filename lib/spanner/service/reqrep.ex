defmodule Spanner.Service.Request do

  use Spanner.Marshalled

  defmarshalled [:service, :req_id, :parameters, :reply_to]

  def validate(request) do
    cond do
      request.service == nil ->
        {:error, {:empty_field, :service}}
      request.reply_to == nil ->
        {:error, {:empty_field, :reply_to}}
      true ->
        {:ok, request}
    end
  end
end

defmodule Spanner.Service.Response do

  use Spanner.Marshalled

  defmarshalled [:service, :req_id, :response]

  def validate(response) do
    cond do
      response.service == nil ->
        {:error, {:empty_field, :service}}
      true ->
        {:ok, response}
    end
  end

end
