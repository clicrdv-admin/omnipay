
# https://github.com/bitpay/ruby-client
require 'bitpay'

# BitPay adapter for omnipay
# Bitpay API documentation https://bitpay.com/downloads/bitpayApi.pdf

module Omnipay
  module Adapters

    class BitPay

      class Error < ::StandardError ; end

      def initialize(config = {})

        if config[:client_id].nil?
          raise ArgumentError.new("missing :client_id (BitPay API Key")
        end

        @client = ::BitPay::Client.new config[:client_id]
        
      end


      # Request phase : defines the redirection to the payment gateway
      #
      # Inputs 
      # * amount (integer) : the amount in cents to pay
      # * params (Hash) : optional parameters for this payment (transaction_id, title, locale, ...)
      #
      # Outputs: array with 4 elements :
      # * the HTTP method to use ('GET' or 'POST')
      # * the url to call
      # * the parameters (will be in the url if GET, or as x-www-form-urlencoded in the body if POST)
      # * a unique id referencing the transaction. Has to be accessible in the callback phase.

      def request_phase(amount, callback_url, params = {})

        invoice = @client.post 'invoice', {:price => amount.to_f / 100, :currency => 'EUR', :redirectURL => callback_url}

        raise Error.new(invoice['error']) if invoice.include? 'error'

        get_params = {
          :redirectURL => callback_url
        }

        [:transactionSpeed, :posData, :fullNotifications, :notificationEmail, :orderID,
         :itemDesc, :itemCode, :physical,:buyerName, :buyerAddress1, :buyerAddress2,
         :buyerCity, :buyerState, :buyerZip, :buyerCountry, :buyerEmail, :buyerPhone
        ].each do |option|
          get_params[option] = params[option] if params.include? option
        end

        [
          'GET',
          invoice['url'],
          get_params,
          invoice['id']
        ]
        
      end


      # Callback hash : extracts the response hash which will be accessible in the callback action
      #
      # Inputs
      # * params (Hash) : the GET/POST parameters returned by the payment gateway
      #
      # Outputs : a Hash which must contain the following keys :
      # * success (boolean) : was the payment successful or not
      # * amount (integer) : the amount actually paid, in cents, if successful
      # * transaction_id(string) : the unique id generated in the request phase, if successful
      # * error (symbol) : the error code if the payment was not successful
      # * error_message (optional string) : a more detailed message explaining the
      
      def callback_hash(params)

        transaction_id = params['id']
        transaction = @client.get transaction_id
        
        if transaction == nil
          return {
            :success => false,
            :error => Omnipay::INVALID_RESPONSE
          }
        end

        response = {
          :amount => transaction[:price].to_i,
          :transaction_id => transaction_id,
          :success => ['paid', 'confirmed', 'complete'].include?(transaction[:status]),
          :status => transaction[:status]
        }
        
        if transaction[:status] == 'expired'
          response[:error] = Omnipay::CANCELED
        elsif !response[:success]
          response[:error] = Omnipay::INVALID_RESPONSE
        end

        response
      end

    end

  end
end