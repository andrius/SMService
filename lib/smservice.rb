require "timeout"
require "smservice/version"

module SMService
  LOGGER = Logger.new(STDERR)

  ENDPOINT_OUT = 'tcp://proxy:6660'
  ENDPOINT_IN = 'tcp://proxy:6661'

  REGISTER_WAIT_TIME = 'infinite'
  KEEPALIVE_WAIT_TIME = 30

  attr_accessor :socket_in, :socket_out
  attr_reader :service_name

  def initialize(name:)
    @service_name = name

    context = ZMQ::Context.new
    @socket_in = context.socket ZMQ::DEALER
    @socket_out = context.socket ZMQ::DEALER

    @socket_in.setsockopt ZMQ::IDENTITY, service_name
    @socket_in.connect ENDPOINT_IN

    @socket_out.setsockopt ZMQ::IDENTITY, service_name
    @socket_out.connect ENDPOINT_OUT
  end

  def register!(wait_time: REGISTER_WAIT_TIME)
    if wait_time.to_f <= 0
      loop do
        register!
        break if registered?
        # not registered, retrying in 10 seconds
        sleep 10
      end
    else
      Timeout::timeout(wait_time) do
        loop do
          register!
          break if registered?
          # not registered, retrying in 10 seconds
          sleep 10
        end
      end
    end
  end

  def keep_alive!(wait_time: KEEPALIVE_WAIT_TIME)
    Thread.start do
      LOGGER.info "Starting registration update loop with periodic interval #{wait_time} sec"
      loop do
        break unless registered?
        sleep wait_time
        service_manager('UPDATE',  [])
      end
      LOGGER.info 'Registration update loop terminated'
    end
  end

  def registered?
    @registered
  end

  def register!
    service_manager('REGISTER',  services: [service_name])
    pull_action
  end

  def service_poller
    loop do
      pull_action
    end
  end

  def start!
    register!
    keep_alive!
    service_poller
  end

  def action_update(headers, message)
    LOGGER.info("Action: UPDATE (successful)")
  end

  def action_register(headers, message)
    if headers['action'] == 'REGISTER' && message['result'] == 'OK'
      @registered = true
      LOGGER.info "Action: REGISTER (successful), headers: #{headers.inspect}, message: #{message.inspect}"
    else
      LOGGER.info "Action: REGISTER (failure), headers: #{headers.inspect}, message: #{message.inspect}"
    end   
  end

private

  # Sending request to the Service Manager
  # 
  def service_manager(action, message)
    LOGGER.info "SM request. Action: #{action.inspect}, message: #{message.inspect}"
    action = {action: action}.to_msgpack
    message = message.to_msgpack
    @socket_in.send_strings [action, message]
  end

  def pull_action
    @socket_in.recv_strings( response = [] )

    headers, message = response
    headers = MessagePack.unpack(headers)
    message = MessagePack.unpack(message)

    LOGGER.info "SM response received by pull_action. Headers: #{headers.inspect}, message: #{message.inspect}"

    # Validates is action_name exists as class method and calling it.
    # In case, if Service Manager return headers['action'] == 'METHOD_NAME',
    # ruby expecting that somethinf like this would be defined:
    #
    # def action_method_name(headers, message)
    #   # ... some business logic here
    # end
    #
    # Two actions defined as part of module, it is :
    # - action_register, that confirms registration of node with Service Manager, and
    # - action_update, that confirms successfule registration update, we need it to support keep-alive
    #
    action_name = "action_#{headers['action'].downcase}".to_sym
    if respond_to? action_name.to_sym
      send(action_name, headers, message)
    end
  end
end

class SMService::Dummy
  include SMService

  def initialize
    super name: 'dummy-ruby'
  end
end
