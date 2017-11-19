require 'timeout'
require 'logger'
require 'msgpack'
require 'ffi-rzmq'
require 'smservice/version'

module SMService
  Thread.abort_on_exception = true

  LOGGER = Logger.new(STDERR)

  ENDPOINT_OUT = 'tcp://proxy:6660'
  ENDPOINT_IN = 'tcp://proxy:6661'

  REGISTER_WAIT_TIME  = 'infinite'
  REGISTER_RETRY      = 10
  KEEPALIVE_WAIT_TIME = 30

  attr_accessor :socket_in, :socket_out
  attr_reader :service_name

  # When registering node, following parameters is mandatory:
  #
  # name: name of service/node with its id;
  # actions: list of actions, should be in lowercase and compatible to naming standard for ruby methods
  # actions could be presented as array or as string if service registering only single action
  #
  # Example:
  # SMService::SomeService.new(name: 'dummy-ruby', actions: %w(a b c ping pong))
  #
  # Following actions should be defined as methods for new service, i.e.
  #
  # def action_ping(headers, message)
  #   LOGGER.info "#{self.class} - Processing action: PING with headers: #{headers.inspect} and message: #{message.inspect}"
  #   # ... business logic here
  #  end
  #
  # Prohibited names for actions is register and update, those are reserved to let service communicate with SM.
  # Check SMService::Dummy source code (in examples folder) for detais
  #
  def initialize(name:, actions: [])
    @service_name = name
    @actions = [%w(ping), actions].flatten.sort.uniq

    context = ZMQ::Context.new
    @socket_in = context.socket ZMQ::DEALER
    @socket_out = context.socket ZMQ::DEALER

    @socket_in.setsockopt ZMQ::IDENTITY, service_name
    @socket_in.connect ENDPOINT_IN

    @socket_out.setsockopt ZMQ::IDENTITY, service_name
    @socket_out.connect ENDPOINT_OUT
  end

  # starting infinite loop in order to process service logic.
  # start! or service_poller methods could be modified implementing different services, i.e.  to run as threaded metod
  def start!
    register
    keep_alive!
    poller!
  end

  def poller!
    Thread.start do
      poller
    end
  end

  def poller
    loop do
      pull
    end
  end

  def register(wait_time: REGISTER_WAIT_TIME)
    if wait_time.to_f <= 0
      loop do
        register_service
        break if registered?
        # not registered, retrying in 10 seconds
        sleep REGISTER_RETRY
      end
    else
      Timeout::timeout(wait_time) do
        loop do
          register_service
          break if registered?
          # not registered, retrying in 10 seconds
          sleep REGISTER_RETRY
        end
      end
    end
  end

  def keep_alive!(wait_time: KEEPALIVE_WAIT_TIME)
    Thread.start do
      LOGGER.info "#{self.class} - Starting registration update loop with periodic interval #{wait_time} sec"
      loop do
        break unless registered?
        sleep wait_time
        request(action: 'UPDATE')
      end
      LOGGER.info 'Registration update loop terminated'
    end
  end

  def registered?
    @registered
  end

  def action_register(headers, message)
    if headers['action'] == 'REGISTER' && message['result'] == 'OK'
      @registered = true
      LOGGER.info "#{self.class} - Action: REGISTER (successful), headers: #{headers.inspect}, message: #{message.inspect}"
    else
      LOGGER.info "#{self.class} - Action: REGISTER (failure), headers: #{headers.inspect}, message: #{message.inspect}"
    end   
  end

  def action_ping(headers, message)
    LOGGER.info "#{self.class} - Processing action 'ping'. Headers: #{headers.inspect}, message: #{message.inspect}"
  end

  def action_update(headers, message)
    LOGGER.info "#{self.class} - Processing action 'update'. Headers: #{headers.inspect}, message: #{message.inspect}"
  end

  # Requesting another service, registered at SM to execute given action, example:
  # execute(action: 'create_customer_portal', message: {my_request: 'should create a customer', my_data: 'add whatever data needed'})
  #
  def execute(action:, message: nil)
    LOGGER.info "#{self.class} - SM execute request. Action: #{action.inspect}, message: #{message.inspect}"
    action = {service: action, reply_to: @service_name}.to_msgpack
    message = message.to_msgpack
    @socket_out.send_strings [action, message]
  end

private

  def register_service
    LOGGER.info "#{self.class} - Registering service #{service_name}"
    request(action: 'REGISTER', message: {services: @actions})
    pull
  end

  # Sending request to the Service Manager
  def request(action:, message: nil)
    LOGGER.info "#{self.class} - SM request. Action: #{action.inspect}, message: #{message.inspect}"
    action = {action: action}.to_msgpack
    message = message.to_msgpack
    @socket_in.send_strings [action, message]
  end

  def pull
    @socket_in.recv_strings( response = [] )

    headers, message = response
    headers = MessagePack.unpack(headers)
    message = MessagePack.unpack(message)

    LOGGER.info "#{self.class} - SM response received by pull. Headers: #{headers.inspect}, message: #{message.inspect}"

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
    action_name = "action_#{(headers['action'] || headers['service']).downcase}".to_sym
    if respond_to? action_name.to_sym
      send(action_name, headers, message)
    else
      LOGGER.error "#{self.class} - Method #{action_name} does not exist in class instance for action name #{headers['action']}"
    end
  end
end
