defmodule Spanner.Command.Request do
  defstruct [:room, :requestor, :command, :args, :options, :reply_to]

  use Spanner.Request
end

defmodule Spanner.Command.Response do
  defstruct [:room, :status, :status_message, :body, :template]

  use Spanner.Response
end
