
# https://github.com/bitpay/ruby-client

# BitPay adapter for omnipay
# Bitpay API documentation https://bitpay.com/downloads/bitpayApi.pdf

module Omnipay
  module Adapters

    class BitPay < Omnipay::Adapter

      require 'bitpay'

      enable_ipn

      config :client_id,              'the bitpay API client id'

      def payment_page_redirection_ipn(params, ipn_url, callback_url)

        invoice_params = {
          :price => params[:amount].to_f / 100,
          :redirectURL => params.redirectURL || callback_url,
          :notificationURL => ipn_url,
          :fullNotifications => true
        }

        [:transactionSpeed, :posData, :notificationEmail, :orderID,
         :itemDesc, :itemCode, :physical,:buyerName, :buyerAddress1, :buyerAddress2,
         :buyerCity, :buyerState, :buyerZip, :buyerCountry, :buyerEmail, :buyerPhone
        ].each do |option|
          invoice_params[option] = params[option] if params.respond_to? option
        end
puts invoice_params.inspect
        invoice = client.post('invoice', invoice_params)

        raise Error.new(invoice['error']) if invoice.include? 'error'

        [
          'GET',
          invoice['url'],
          {}
        ]
      end


      def validate_payment_notification(request)
        invoice_id = request.params['id']
        return payment_error "No transaction id given" if !invoice_id

        transaction = client.get invoice_id
        return payment_error "No transaction found for #{invoice_id}" if transaction == nil

        if ['expired', 'invalid'].include? transaction[:status]
          return status_canceled
        elsif transaction[:status] == 'confirmed'
          return payment_successful transaction[:posData], transaction_id, transaction[:price].to_i
        else
          return payment_successful transaction[:posData], transaction_id, transaction[:status]
        end
      end


      def validate_callback_status(request)
        status_successful
      end

      def client
        @client ||= ::BitPay::Client.new config.client_id
      end

    end

  end
end