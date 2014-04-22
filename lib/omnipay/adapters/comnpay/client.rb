require 'httparty'

module Omnipay
  module Adapters

    # Lightweight client for the comnpay API
    class Comnpay::Client

      include HTTParty
      base_uri ''

      def initialize(tpe_id, secret_key, sandbox)
        @tpe_id = tpe_id
        @secret_key = secret_key

        if sandbox
          @url = 'https://secure.homologation.comnpay.com:60000'
        else
          @url = 'https://secure.comnpay.com:60000'
        end
      end

      # Get a transaction details
      def transaction(transaction_id)
        endpoint = "#{@url}/rest/payment/find?serialNumber=#{@tpe_id}&key=#{@secret_key}&transactionRef=#{transaction_id}"
        response = self.class.post(endpoint, :headers => {'content-type' => "application/x-www-form-urlencoded"})
        return response.parsed_response && response.parsed_response["transaction"][0] && OpenStruct.new(response.parsed_response["transaction"][0])
      end

    end

  end
end