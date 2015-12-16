defmodule Spanner.Response do
  defmacro __using__(_) do
    quote location: :keep do
      def encode(%__MODULE__{}=req) do
        Poison.encode(%{"response" => Map.from_struct(req)})
      end

      def encode!(%__MODULE__{}=req) do
        Poison.encode!(%{"response" => Map.from_struct(req)})
      end

      def decode!(json) do
        Spanner.RequestResponse.decode!(:response, %__MODULE__{}, json)
      end

      def decode(json) do
        Spanner.RequestResponse.decode(:response, %__MODULE__{}, json)
      end
    end
  end
end
