# Omnipay adapter for mangopay
# documentation : http://docs.mangopay.com/api-references/

require 'omnipay/adapters/mangopay/mangopay_client'

module Omnipay::Adapters
  class Mangopay < Omnipay::Adapter

    # No ipn, everything in the callback page

    config :client_id,              'the mangopay API client id'
    config :client_passphrase,      'the mangopay API client passphrase'
    config :wallet_id,              'the wallet to credit'

    custom_payment_param :payer_id, 'the mangopay user id of the payer',          :mandatory => true
    custom_payment_param :fees,     'the (percent) fees to take on the payment',  :default => 0


    # ================
    # Omnipay handlers
    # ================
    def payment_page_redirection(params, callback_url)
      redirect_url = create_web_payin(params, callback_url)

      # Generate the path and query parameters from the returned redirect_url string
      uri = URI(redirect_url)

      return [
        'GET',
        "#{uri.scheme}://#{uri.host}#{uri.path}",
        Rack::Utils.parse_nested_query(uri.query)
      ]
    end


    def validate_payment_notification(request)
      transaction_id = request.params['transactionId']
      return payment_error "No transaction_id given" unless transaction_id
      validate_payin(transaction_id)
    end


    def validate_callback_status(request)
      transaction_id = request.params['transactionId']
      return payment_error "No transaction_id given" unless transaction_id
      validate_payin(transaction_id) # Only one way to get the status, reuse it
    end


    # =======================
    # The mangopay API client
    # =======================
    def client
      @client ||= MangopayClient.new(config.client_id, config.client_passphrase, :sandbox => !!config.sandbox)
    end


    private


    # Create a mangopay web paying
    def create_web_payin(params, callback_url)
      amount, fees = get_amount_and_fees(params)

      payin_params = {
        :AuthorId =>          params.payer_id, 
        :DebitedFunds => {
          :Currency =>        params.currency,
          :Amount   =>        amount
         },
        :Fees => {
          :Currency =>        params.currency,
          :Amount =>          fees
        },
        :CreditedWalletId =>  config.wallet_id,
        :ReturnURL =>         callback_url,
        :Culture =>           params.locale.upcase,
        :CardType =>          'CB_VISA_MASTERCARD',
        :SecureMode =>        'FORCE'
      }

      payin = client.post '/payins/card/web', payin_params

      # Return the transaction reference, and the full redirection url
      return payin['RedirectURL']
    end


    # Determine the amount and fees in cents from the payment params
    def get_amount_and_fees(params)
      amount_in_cents = params.amount
      fees_percent    = params.fees

      fees = (amount_in_cents * fees_percent).round
      amount_in_cents -= fees

      return [amount_in_cents, fees]
    end


    # Return the hash matching a payin
    def validate_payin(transaction_id)

      begin
        payin = client.get "/payins/#{transaction_id}"
      rescue MangopayClient::Error => e
        return payment_error "Cannot fetch the payin with id #{transaction_id}"
      end

      # Check if the response is valid
      if payin['code'] != 200
        return payment_error "Wrong API response : #{payin['code']}"
      end

      # Successful transaction
      if payin['Status'] == 'SUCCEEDED'
        amount = payin['DebitedFunds']['Amount'].to_i
        reference = payin['Tag']
        transaction_id = transaction_id

        return payment_successful amount, reference, transaction_id
      else

        # Cancelation
        if ['101001', '101002'].include? payin['ResultCode']
          return payment_canceled

        # Failure
        else
          return payment_failed "Refused payment for transaction #{transaction_id}.\nCode : #{payin['ResultCode']}\nMessage : #{payin['ResultMessage']}"
        end
      end
    end

  end

end
