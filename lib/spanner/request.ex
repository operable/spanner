defmodule Spanner.Request do
  defmacro __using__(_) do
    quote location: :keep do
      def encode!(%__MODULE__{}=req),
        do: %{"request" => Map.from_struct(req)}

      def decode!(json),
        do: Spanner.RequestResponse.decode!(:request, %__MODULE__{}, json)
    end
  end
end
