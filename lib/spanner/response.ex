defmodule Spanner.Response do
  defmacro __using__(_) do
    quote location: :keep do
      def encode!(%__MODULE__{}=req),
        do: %{"response" => Map.from_struct(req)}

      def decode!(json),
        do: Spanner.RequestResponse.decode!(:response, %__MODULE__{}, json)
    end
  end
end
