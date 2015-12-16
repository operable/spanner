defmodule Spanner.Request do
  defmacro __using__(_) do
    quote location: :keep do
      def encode(%__MODULE__{}=req) do
        Poison.encode(%{"request" => Map.from_struct(req)})
      end

      def encode!(%__MODULE__{}=req) do
        Poison.encode!(%{"request" => Map.from_struct(req)})
      end

      def decode!(json) do
        Spanner.RequestResponse.decode!(:request, %__MODULE__{}, json)
      end

      def decode(json) do
        Spanner.RequestResponse.decode(:request, %__MODULE__{}, json)
      end
    end
  end
end
