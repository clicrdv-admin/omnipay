# The root Omnipay module. Used for defining its global configuration
module Omnipay

  autoload :Gateway, 'omnipay/gateway'
  autoload :AutosubmitForm, 'omnipay/autosubmit_form'
  autoload :Configuration, 'omnipay/configuration'
  autoload :Gateways, 'omnipay/gateways'
  autoload :Middleware, 'omnipay/middleware'

  # Error code for an untreatable response
  INVALID_RESPONSE = :invalid_response

  # Error code for a user-initiated payment failure
  CANCELATION = :cancelation

  # Error code for a valid response but a failed payment
  PAYMENT_REFUSED = :payment_refused

  # Error code for a signature mismatch
  WRONG_SIGNATURE = :wrong_signature



  # Accessors to the configured gateways
  def self.gateways
    @gateways ||= Omnipay::Gateways.new
  end


  # Syntaxic sugar for adding a new gateway
  def self.use_gateway(opts = {}, &block)
    self.gateways.push(opts, &block)
  end


  # Accessor to the global configuration
  # @return [Configuration]
  def self.configuration
    Configuration.instance
  end

  # Allows to configure omnipay via a block
  #
  # Example use : 
  # 
  #   Omnipay.configure do |config|
  #     config.secret_token = "a-secret-token"
  #   end
  def self.configure
    yield configuration
  end

end

# Rails bindings
require 'omnipay/railtie' if defined?(Rails)