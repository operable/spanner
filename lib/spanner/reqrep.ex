defmodule Spanner.DecodeError do
  defexception [:message, :json]

  def key_error(:request) do
    :missing_request_key
  end
  def key_error(:response) do
    :missing_response_key
  end

end

defmodule Spanner.RequestResponse do

  def decode!(key, struct, json) do
    case decode(key, struct, json) do
      {:ok, s} -> s
      {:error, {reason, json}} ->
        raise Spanner.DecodeError, [message: "#{inspect reason}", json: json]
      error ->
        raise Spanner.DecodeError, [message: "#{inspect error}"]
    end
  end

  def decode(key, struct, json) when is_binary(json) do
    case Poison.decode(json) do
      {:ok, obj} when is_map(obj) ->
        decode(key, struct, obj)
      {:ok, json} ->
        {:error, {:wrong_json_type, json}}
      error ->
        error
    end
  end
  def decode(key, struct, obj) when is_map(obj) do
    case Map.has_key?(obj, Atom.to_string(key)) do
      false ->
        {:error, {Spanner.DecodeError.key_erro(key), obj}}
      true ->
        obj = obj[Atom.to_string(key)]
        s = struct
        {:ok, Enum.reduce(Map.keys(s), s,
            fn(field, s) ->
              objfield = Atom.to_string(field)
              case Map.get(obj, objfield) do
                nil ->
                  s
                value ->
                  Map.put(s, field, value)
              end
            end)}
    end
  end
end
