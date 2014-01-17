# Omnipay adapter for mangopay
# documentation : http://docs.mangopay.com/api-references/
#
# Configuration :
# - client_id:string (mandatory) : client id of your mangopay account
# - client_passphrase:string (mandatory) : the passphrase for your account
# - wallet_id:string (mandatory) : the wallet to be credited with the payments

require 'omnipay/adapters/mangopay/client'

module Omnipay
  module Adapters

    class Mangopay

      attr_reader :client

      def initialize(callback_url, config = {})

        raise ArgumentError.new("Missing client_id, client_passphrase, or wallet_id parameter") unless [config[:client_id], config[:client_passphrase], config[:wallet_id]].all?

        @client = Client.new(config[:client_id], config[:client_passphrase], :sandbox => !!config[:sandbox])
        @callback_url = callback_url
        @wallet_id = config[:wallet_id]

      end


      def request_phase(amount, params = {})

        transaction_id, redirect_url = create_web_payin(amount, params)

        # Generate the path and query parameters from the returned redirect_url string
        uri = URI(redirect_url)

        return [
          'GET', 
          "#{uri.scheme}://#{uri.host}#{uri.path}", 
          Rack::Utils.parse_nested_query(uri.query), 
          transaction_id
        ]

      end


      def callback_hash(params)

        transaction_id = params[:transactionId]

        begin
          response = @client.get "/payins/#{transaction_id}"
        rescue Mangopay::Client::Error => e
          return {
            :success => false,
            :error => Omnipay::INVALID_RESPONSE,
            :error_message => "Could not fetch details of transaction #{transaction_id}"
          }
        end

        # Check if the response is valid
        if response['code'] != 200
          return {
            :success => false,
            :error => Omnipay::INVALID_RESPONSE
          }
        end


        # Successful transaction
        if response['Status'] == 'SUCCEEDED'
          {
            :success => true,
            :amount => response['DebitedFunds']['Amount'],
            :transaction_id => transaction_id
          }
        else

          # Cancelation
          if ['101001', '101002'].include? response['ResultCode']
            {
              :success => false,
              :error => Omnipay::CANCELATION
            }
          else
            {
              :success => false,
              :error => Omnipay::PAYMENT_REFUSED,
              :error_message => "Refused payment for transaction #{transaction_id}.\nCode : #{response['ResultCode']}\nMessage : #{response['ResultMessage']}"
            }
          end
        end
      end


      private

      def create_web_payin(amount, params)

        # Create a user
        random_key = "#{Time.now.to_i}-#{(0...3).map { ('a'..'z').to_a[rand(26)] }.join}"
        user_params = {
          :Email => "user-#{random_key}@host.tld",
          :FirstName => "User #{random_key}",
          :LastName => "User #{random_key}",
          :Birthday => Time.now.to_i,
          :Nationality => "FR",
          :CountryOfResidence => "FR"
        }

        user_id = (@client.post('/users/natural', user_params))["Id"]

        # Create the web payin        
        payin_params = {
          :AuthorId => user_id, 
          :DebitedFunds => {
            :Currency => 'EUR',
            :Amount => amount
          },
          :Fees => {
            :Currency => 'EUR',
            :Amount => 0
          },
          :CreditedWalletId => @wallet_id,
          :ReturnURL => @callback_url,
          :Culture => (params[:locale] || 'fr').upcase,
          :CardType => 'CB_VISA_MASTERCARD',
          :SecureMode => 'FORCE'
        }

        payin = @client.post '/payins/card/web', payin_params

        # Return the transaction reference, and the full redirection url
        return [payin["Id"], payin["RedirectURL"]]
      end

    end

  end
end