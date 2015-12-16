defmodule Spanner.Service.Request do
  defstruct [:service, :req_id, :parameters, :reply_to]

  use Spanner.Request
end

defmodule Spanner.Service.Response do
  defstruct [:service, :req_id, :response]

  use Spanner.Response
end
