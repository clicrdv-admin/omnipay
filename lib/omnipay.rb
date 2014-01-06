require 'singleton'

module Omnipay

  autoload :Gateway, 'omnipay/gateway'
  autoload :Adapter, 'omnipay/adapter'
  autoload :RequestPhase, 'omnipay/request_phase'
  autoload :CallbackPhase, 'omnipay/callback_phase'
  autoload :AutosubmitForm, 'omnipay/autosubmit_form'
  autoload :Signer, 'omnipay/signer'

  # Error codes
  INVALID_RESPONSE = :invalid_response
  CANCELATION = :cancelation
  PAYMENT_REFUSED = :payment_refused
  WRONG_SIGNATURE = :wrong_signature

  # Configuration
  class Configuration
    include Singleton
    attr_accessor :secret_token
  end

  def self.configuration
    Configuration.instance
  end

  def self.configure
    yield configuration
  end

end