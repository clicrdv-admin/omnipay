module Omnipay

  autoload :Gateway, 'omnipay/gateway'
  autoload :Adapter, 'omnipay/adapter'
  autoload :RequestPhase, 'omnipay/request_phase'
  autoload :CallbackPhase, 'omnipay/callback_phase'
  autoload :AutosubmitForm, 'omnipay/autosubmit_form'

  # Error codes
  INVALID_RESPONSE = :invalid_response
  CANCELATION = :cancelation
  PAYMENT_REFUSED = :payment_refused

end