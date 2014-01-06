# Class responsible for signing the outgoing payments in the request phase, 
# and validating them in the callback phase

require 'openssl'

module Omnipay
  class Signer

    def initialize(transaction_id, amount, context)
      @transaction_id = transaction_id
      @amount = amount
      @context = context || {}
    end

    def signature
      to_sign = "#{secret_token}:#{@transaction_id}:#{@amount}:#{self.class.hash_to_string @context}"
      CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', secret_token, to_sign)))
    end


    # Unique key : to configure globally
    def secret_token
      Omnipay.configuration.secret_token
    end

    private

    def self.hash_to_string(hash)
      # key/values appended by alphabetical key order
      hash.sort_by{|k,_|k}.flatten.join('')
    end

  end
end