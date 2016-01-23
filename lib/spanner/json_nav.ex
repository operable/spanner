defmodule Spanner.JsonNavigationError do
  defexception message: nil, reason: nil, field: nil
end

defmodule Spanner.JsonNavigator do

  alias Spanner.JsonNavigationError, as: NavigationError

  defmacro __using__(_) do
    quote do
      alias unquote(__MODULE__)
      alias Spanner.JsonNavigationError
    end
  end

  def get!(json, path) when (is_map(json) or is_list(json)) and is_list(path) do
    retrieve_and_verify!(json, path)
  end

  defp retrieve_and_verify!(value, []) do
    value
  end
  defp retrieve_and_verify!(json, [{field, type}|t]) when is_binary(field) do
    unless is_map(json) do
      raise NavigationError, field: field, reason: :wrong_type, message: "Expected map but found #{inspect json}"
    end
    case Map.get(json, field) do
      nil ->
        raise NavigationError, field: field, reason: :missing_key, message: "#{field} is missing"
      value ->
        retrieve_and_verify!(verify_type!(value, type, field), t)
    end
  end
  defp retrieve_and_verify!(json, [field|t]) when is_binary(field) do
    unless is_map(json) do
      raise NavigationError, field: field, reason: :wrong_type, message: "Expected map but found #{inspect json}"
    end
    case Map.get(json, field) do
      nil ->
        raise NavigationError, field: field, reason: :missing_key, message: "#{field} is missing"
      value ->
        retrieve_and_verify!(value, t)
    end
  end
  defp retrieve_and_verify!(json, [{field, type}|t]) when is_integer(field) do
    unless is_list(json) do
      raise NavigationError, field: field, reason: :wrong_type, message: "Expected array but found #{inspect json}"
    end
    case Enum.at(json, field) do
      nil ->
        raise NavigationError, field: field, reason: :wrong_length, message: "Array index #{field} doesn't exist"
      value ->
        retrieve_and_verify!(verify_type!(value, type, field), t)
    end
  end
  defp retrieve_and_verify!(json, [field|t]) when is_integer(field) do
    unless is_list(json) do
      raise NavigationError, field: field, reason: :wrong_type, message: "Expected array but found #{inspect json}"
    end
    case Enum.at(json, field) do
      nil ->
        raise NavigationError, field: field, reason: :wrong_length, message: "Expected array to be at least #{field} long: #{inspect json}"
      value ->
        retrieve_and_verify!(value, t)
    end
  end

  defp verify_type!(value, :string, _field) when is_binary(value) do
    value
  end
  defp verify_type!(value, :integer, _field) when is_integer(value) do
    value
  end
  defp verify_type!(value, :float, _field) when is_float(value) do
    value
  end
  defp verify_type!(value, type, _field) when type in [:array, :list] and is_list(value) do
    value
  end
  defp verify_type!(value, :boolean, _field) when value in [true, false] do
    value
  end
  defp verify_type!(value, type, _field) when type in [:map, :object] and is_map(value) do
    value
  end
  defp verify_type!(value, type, field) do
    raise NavigationError, field: field, reason: :wrong_type, message: "Expected #{type} but found #{inspect value}"
  end

end
