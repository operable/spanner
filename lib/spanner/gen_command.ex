defmodule Spanner.GenCommand do
  @moduledoc """
  Generic bot command support.

  Elixir-based commands should see `Spanner.GenCommand.Base`, as it
  provides several helper macros that remove much of the boilerplate
  from implementation, and also provides several helpful compile-time
  validity checks.

  If you are implementing a pure Erlang command, however, you can just
  implement this behaviour directly as one normally does.
  """

  @typedoc """
  The state supplied to the callback module implementation
  functions. This will be created by `callback_module.init/2`,
  maintained by the `GenCommand` infrastructure, and passed into
  `handle_message/2`
  """
  @type callback_state() :: term()

  @typedoc """
  Used to indicate which topic on the message bus replies should be
  posted to.
  """
  @type message_bus_topic() :: String.t

  @typedoc """
  The basename of the template file, used to render the json output into a text
  response.
  """
  @type template() :: String.t

  @typedoc """
  Commands and services can send back arbitrary responses (as long
  as they can serialize to JSON).
  """
  @type command_response() :: term()

  @typedoc """
  Interactions with services from within commands is done through a
  "service proxy", which encapsulates the details of interacting with
  the message bus.
  """
  @opaque service_proxy() :: pid()

  @doc """
  Start a command in the context of a bundle supervision tree.
  """
  @callback start_link() :: pid()

  @doc """
  Initializes the callback module's internal state.

  If your command is stateless and requires no interaction with
  services, this can return any value.

  If you *do* need to interact with services, you must store the
  supplied service proxy in your state somehow. If you don't, it will
  not be available in handle_message/2.
  """
  @callback init(term(), service_proxy())
            :: {:ok, callback_state()} |
               {:error, term()}

  @callback handle_message(Command.Request.t, callback_state())
            :: {:reply, message_bus_topic(), command_response(), callback_state()} |
               {:reply, message_bus_topic(), template(), command_response(), callback_state()} |
               {:noreply, callback_state()}

  @doc "The name by which the command is referred to."
  @callback command_name() :: String.t

  @doc "The name of the bundle of which the command is a member."
  @callback bundle_name() :: String.t

  @doc """
  Return all the invocation rules defined for a given command.

  ## Example

      > MyCommand.rules
      [
        "when command is my-command must have bundle:admin",
        "when command is my-command with arg[0] == 'foo' must have bundle:read"
      ]

  """
  @callback rules() :: [String.t]

  @doc """
  Return the names of the permissions that the command depends on.
  """
  @callback permissions() :: [String.t]

  @doc """
  Return descriptors for all the options a command declares.

  ## Example

      > CommandWithMultipleOptions.options
      [
        %{name: "option_1", type: "string", required: true},
        %{name: "option_2", type: "boolean", required: false},
        %{name: "option_3", type: "string", required: false}
      ]

  """
  @callback options() :: [map()]


  @doc """
  Indicates whether a command should skip permission checks or not.
  """
  @callback primitive?() :: boolean()

  @doc """
  Returns `true` if `module` implements the
  `#{inspect __MODULE__}` behaviour.
  """
  def is_command?(module) do
    attributes = try do
                   # Only Elixir modules have `__info__`
                   module.__info__(:attributes)
                 rescue
                   UndefinedFunctionError ->
                     # Erlang modules use `module_info`
                     module.module_info(:attributes)
                 end
    behaviours = Keyword.get(attributes, :behaviour, [])
    __MODULE__ in behaviours
  end

  ########################################################################
  # Implementation

  use GenServer

  require Logger
  alias Spanner.Command

  ## Fields
  #
  # * `mq_conn`: Connection to the message bus
  # * `cb_module`: callback module; the module implementing the specific
  #   command details
  # * `cb_state`: An arbitrary term for when the callback module needs
  #   to keep state of its own. Initial value is whatever
  #   `cb_module:init/1` returns.
  # * `topic`: message bus topic to which commands are sent; this is
  #   what we listen to to get jobs.
  @typep state :: %__MODULE__{mq_conn: Carrier.Messaging.Connection.connection,
                              cb_module: module(),
                              cb_state: callback_state(),
                              topic: String.t}
  defstruct [mq_conn: nil,
             cb_module: nil,
             cb_state: nil,
             topic: nil]

  @doc """
  Starts the command.

  ## Arguments

  * `module`: the module implementing the command
  * `args`: will be passed to `module.info/1` to generate callback
    state

  ## Example

      defmodule MyCommand do
        ...

        def start_link(),
          do: Spanner.GenCommand.start_link(__MODULE__, [x,y,z])

        ...
      end

  """
  def start_link(module, args),
    do: GenServer.start_link(__MODULE__, [module: module, args: args])

  @doc """
  Callback for the underlying `GenServer` implementation of
  `GenCommand`. Calls `module.init/2` to set up callback state.

  """
  @spec init(Keyword.t) :: {:ok, Spanner.GenCommand.state} | {:error, term()}
  def init([module: module, args: args]) do
    # Establish a connection to the message bus and subscribe to
    # the appropriate topics
    {:ok, conn} = Carrier.Messaging.Connection.connect

    relay_id = Carrier.CredentialManager.get().id

    [topic, reply_topic] = topics = [get_topic(module, relay_id), get_reply_topic(module, relay_id)]
    for topic <- topics do
      Logger.debug("#{inspect module}: Command subscribing to #{topic}")
      Carrier.Messaging.Connection.subscribe(conn, topic)
    end

    # NOTICE: we are currently sharing the message queue connection
    # between the GenCommand process and the ServiceProxy
    # process. This is OK for our current uses (MQTT provided by
    # emqttd) because the connection is itself just a PID. If in the
    # future we were to change message buses or MQTT providers and the
    # resulting connection were to be more complex (carrying around
    # extra state, for example), we'd likely need to have separate
    # connections.

    # Note, the reply topic is only used in the service proxy
    service_proxy = Spanner.ServiceProxy.new(conn, reply_topic)

    case module.init(args, service_proxy) do
      {:ok, state} ->
        {:ok, %__MODULE__{mq_conn: conn,
                          cb_module: module,
                          cb_state: state,
                          topic: topic}}
      {:error, reason} = error ->
        Logger.error("#{inspect module}: Command initialization failed: #{inspect reason}")
        error
    end
  end

  def handle_info({:publish, topic, message},
                  %__MODULE__{topic: topic}=state) do
    case Carrier.Signature.extract_authenticated_payload(message) do
      {:ok, payload} ->
        req = Command.Request.decode!(payload)
        case state.cb_module.handle_message(req, state.cb_state) do
          {:reply, reply_to, template, reply, cb_state} ->
            new_state = %{state | cb_state: cb_state}
            {:noreply, send_ok_reply(reply, template, reply_to, new_state)}
          {:reply, reply_to, reply, cb_state} ->
            new_state = %{state | cb_state: cb_state}
            {:noreply, send_ok_reply(reply, reply_to, new_state)}
          {:noreply, cb_state} ->
            new_state = %{state | cb_state: cb_state}
            {:noreply, new_state}
        end
      {:error, _} ->
        Logger.error("Message signature not verified! #{inspect message}")
        {:noreply, state}
    end
  end
  def handle_info(_, state),
    do: {:noreply, state}

  ########################################################################

  defp send_ok_reply(reply, template, reply_to, state) when is_map(reply) or is_list(reply) do
    resp = Command.Response.encode!(%Command.Response{status: :ok, body: reply, template: template})
    Carrier.Messaging.Connection.publish(state.mq_conn, resp, routed_by: reply_to)
    state
  end

  defp send_ok_reply(reply, reply_to, state) when is_map(reply) or is_list(reply) do
    resp = Command.Response.encode!(%Command.Response{status: :ok, body: reply})
    Carrier.Messaging.Connection.publish(state.mq_conn, resp, routed_by: reply_to)
    state
  end
  defp send_ok_reply(reply, reply_to, state),
    do: send_ok_reply(%{body: [reply]}, reply_to, state)

  ########################################################################

  defp get_topic(module, relay_id),
    do: "/bot/commands/#{relay_id}/#{module.bundle_name()}/#{module.command_name()}"

  defp get_reply_topic(module, relay_id),
    do: "#{get_topic(module, relay_id)}/reply"

end
