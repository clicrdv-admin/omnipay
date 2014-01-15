require 'openssl'

module Omnipay

  # Class responsible for computing a signature of a payment.
  class Signer

    # @param transaction_id [String] the transactions's unique identifier
    # @param amount [Integer] the amount **in cents** of the transaction
    # @param context [Hash] the transaction's context hash
    # @return [Signer]
    def initialize(transaction_id, amount, context)
      @transaction_id = transaction_id
      @amount = amount
      @context = context || {}
    end

    # Actually computes the signature
    # @return [String] The computed signature
    def signature
      to_sign = "#{secret_token}:#{@transaction_id}:#{@amount}:#{self.class.hash_to_string @context}"
      CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', secret_token, to_sign)))
    end

    private

    def secret_token
      Omnipay.configuration.secret_token
    end

    def self.hash_to_string(hash)
      # key/values appended by alphabetical key order
      hash.sort_by{|k,_|k}.flatten.join('')
    end

  end
end