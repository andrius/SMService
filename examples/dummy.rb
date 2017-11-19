class SMService::Dummy
  include SMService

  def initialize
    super name: 'dummy_ruby', actions: 'someaction'
  end

  def action_someaction(headers, message)
    LOGGER.info("Processing action 'someaction'. Headers: #{headers.inspect}, message: #{message.inspect}")
  end
end
