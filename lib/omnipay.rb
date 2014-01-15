require 'singleton'

# The root Omnipay module. Used for defining its global configuration
module Omnipay

  autoload :Gateway, 'omnipay/gateway'
  autoload :Adapter, 'omnipay/adapter'
  autoload :RequestPhase, 'omnipay/request_phase'
  autoload :CallbackPhase, 'omnipay/callback_phase'
  autoload :AutosubmitForm, 'omnipay/autosubmit_form'
  autoload :Signer, 'omnipay/signer'

  # Error code for an untreatable response
  INVALID_RESPONSE = :invalid_response

  # Error code for a user-initiated payment failure
  CANCELATION = :cancelation

  # Error code for a valid response but a failed payment
  PAYMENT_REFUSED = :payment_refused

  # Error code for a signature mismatch
  WRONG_SIGNATURE = :wrong_signature


  # The global Omnipay configuration singleton
  class Configuration
    include Singleton
    attr_accessor :secret_token
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