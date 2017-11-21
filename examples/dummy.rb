class SMService::Dummy
  include SMService

  def initialize
    super name: 'dummy_ruby', actions: 'someaction'
  end

  def action_someaction(headers, message)
    LOGGER.info "#{self.class} - Processing action 'someaction'. Headers: #{headers.inspect}, message: #{message.inspect}"

    if headers['reply_to']
      # sending reply back
      LOGGER.info "#{self.class} - Action 'someaction' sending reply"

      execute action: 'REPLY',
              reply_to: headers['reply_to'],
              message:  {status: 'OK', whatever: 'add it here'}

      LOGGER.info "#{self.class} - Action 'someaction' reply sent"
    end

    LOGGER.info "#{self.class} - Terminating action 'someaction'"

  end
end
