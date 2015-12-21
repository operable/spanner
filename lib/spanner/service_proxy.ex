defmodule Spanner.ServiceProxy do
  @moduledoc """
  Abstracts interaction with services.
  """
  alias Spanner.Service
  require Logger

  @default_service_timeout 5000 # milliseconds

  @doc """
  Starts (and links) a new ServiceProxy agent, returning the agent.

  ## Arguments

  * `mq_conn`: message queue connection
  * `reply_topic`: message queue topic to which service responses
    should be routed, and to which the agent will listen for said
    responses.

  """
  @spec new(Carrier.Messaging.Connection.connection(), String.t) :: pid()
  def new(mq_conn, reply_topic) do
    Logger.info("#{inspect __MODULE__}: Starting agent")
    {:ok, agent} = Agent.start_link(fn ->
      %{mq_conn: mq_conn, reply_topic: reply_topic}
    end)
    Logger.info("#{inspect __MODULE__}: Agent #{inspect agent} started")
    agent
  end

  @doc """
  Executes a blocking service call.

  The result of the function will be whatever the service returned,
  but filtered through a round of JSON encoding / decoding. That is,
  if the service returns a JSON object, the result of this function
  call will be a decoded map with string keys. If it returns a JSON
  array of JSON objects, you'll get a list of maps. If it returns a
  string, you'll get a string, and so on.

  ## Arguments

  * `service_proxy`: reference to the proxy that will be making the
    call on your behalf.
  * `service_opts`: map of options to configure the service
    request. Must have `service` and `parameters` keys.
  * `timeout`: optional waiting period for a service to
    respond. Defaults to #{@default_service_timeout} milliseconds

  """
  # TODO Why not just pass 'service' and 'parameters' as explicit options? Why bother with a map?
  def call(service_proxy, service_opts, timeout \\ @default_service_timeout) do
    mq_conn = message_queue(service_proxy)
    reply_topic = reply_topic(service_proxy)

    service_req = %Service.Request{service: service_opts.service,
                                   parameters: service_opts.parameters,
                                   reply_to: reply_topic}
    Carrier.Messaging.Connection.publish(mq_conn,
                                         Service.Request.encode!(service_req),
                                         routed_by: "/bot/services/#{service_opts.service}")
    receive do
      {:publish, ^reply_topic, message} ->
        case Carrier.CredentialManager.verify_signed_message(message) do
          {true, payload} ->
            res = Service.Response.decode!(payload)
            res.response
          false ->
            raise RuntimeError, message: "Message signature not verified! #{inspect message}"
          end
    after timeout ->
        raise RuntimeError, message: "Timed out waiting for reply from #{service_opts.service}"
    end
  end

  defp message_queue(service_proxy),
    do: get(service_proxy, :mq_conn)

  defp reply_topic(service_proxy),
    do: get(service_proxy, :reply_topic)

  defp get(agent, key),
    do: Agent.get(agent, &Map.get(&1, key))

end
