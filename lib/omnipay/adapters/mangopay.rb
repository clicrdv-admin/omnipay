# Omnipay adapter for mangopay
# documentation : http://docs.mangopay.com/api-references/
#
# Configuration :
# - client_id:string (mandatory) : client id of your mangopay account
# - client_passphrase:string (mandatory) : the passphrase for your account
# - wallet_id:string (mandatory) : the wallet to be credited with the payments

require_relative 'mangopay/client'


module Omnipay
  module Adapters

    class Mangopay


      def initialize(callback_url, config = {})

        raise ArgumentError.new("Missing client_id, client_passphrase, or wallet_id parameter") unless [config[:client_id], config[:client_passphrase], config[:wallet_id]].all?

        @client = Client.new(config[:client_id], config[:client_passphrase], :sandbox => !!config[:sandbox])
        @callback_url = callback_url
        @wallet_id = config[:wallet_id]

      end


      def request_phase(amount, params = {})

        # Create a user
        user_creation_response = @client.post('/users/natural', user_params)
        user_id = user_creation_response["Id"]

        # Create the payment
        payment_creation_response = @client.post(
          '/payins/card/web', 
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
          :Culture => 'FR',
          :CardType => 'CB_VISA_MASTERCARD',
          :SecureMode => 'FORCE'
        )

        transaction_id = payment_creation_response["Id"]
        redirect_url = payment_creation_response["RedirectURL"]
        uri = URI(redirect_url)

        url = "#{uri.scheme}://#{uri.host}#{uri.path}"
        params = Rack::Utils.parse_nested_query(uri.query)

        ['GET', url, params, transaction_id]

      end


      def callback_hash(params)

        transaction_id = params[:transactionId]

        response = @client.get "/payins/#{transaction_id}"

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
              :error => Omnipay::PAYMENT_REFUSED
            }
          end
        end
      end


      private


      def user_params
        random_key = "#{Time.now.to_i}-#{(0...3).map { ('a'..'z').to_a[rand(26)] }.join}"

        {
          :Email => "user-#{random_key}@host.tld",
          :FirstName => "User #{random_key}",
          :LastName => "User #{random_key}",
          :Birthday => Time.now.to_i,
          :Nationality => "FR",
          :CountryOfResidence => "FR"
        }
      end

    end

  end
end