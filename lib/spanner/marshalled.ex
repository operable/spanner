defmodule Spanner.EncodingError do
  defexception [:message, :json]
end

defmodule Spanner.Marshalled do

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: [defmarshalled: 1]
      Module.register_attribute(__MODULE__, :field_mappings, accumulate: false, persist: false)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro defmarshalled(fields) do
    field_mappings = Enum.map(fields, fn(field) -> {Atom.to_string(field), field} end)
    quote location: :keep do

      defstruct unquote(fields)
      @field_mappings unquote(field_mappings)
    end
  end

  defmacro __before_compile__(_) do
    caller = __CALLER__.module
    has_validate = Module.defines?(caller, {:validate, 1})
    {:__block__, [], [gen_encoder(), gen_decoder(has_validate)]}
  end

  defp gen_encoder do
    quote do
      def encode!(%__MODULE__{}=data) do
        case Map.from_struct(data) do
          {:error, reason} ->
            raise Spanner.EncodingError, [message: inspect(reason), json: inspect(data)]
          m ->
            m
        end
      end
    end
  end
  defp gen_decoder(false) do
    quote do
      def decode!(data) do
        case Enum.reduce(@field_mappings, %__MODULE__{},
              fn({dname, sname}, accum) ->
                Map.put(accum, sname, Map.get(data, dname))
              end) do
          {:error, reason} ->
            raise Spanner.EncodingError, [message: inspect(reason), json: inspect(data)]
          populated ->
            populated
        end
      end
    end
  end
  defp gen_decoder(true) do
    quote do
      def decode!(data) do
        populated = Enum.reduce(@field_mappings, %__MODULE__{},
          fn({dname, sname}, accum) ->
            Map.put(accum, sname, Map.get(data, dname))
          end)
        case validate(populated) do
          {:ok, populated} ->
            populated
          {:error, {:empty_field, field}} ->
            raise Spanner.EncodingError, [message: "#{__MODULE__}.#{field} is empty", json: data]
          {:error, reason} ->
            raise Spanner.EncodingError, [message: inspect(reason), json: data]
        end
      end
    end
  end

end
